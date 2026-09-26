import CoreMotion
import SpriteKit
import SwiftUI

struct RemoteSceneSurface: UIViewRepresentable {
    let theme: Theme
    let configuration: SceneConfiguration
    let active: Bool
    let reduceMotion: Bool

    func makeUIView(context: Context) -> RemoteSceneSKView {
        let view = RemoteSceneSKView()
        view.ignoresSiblingOrder = true
        view.isOpaque = true
        view.backgroundColor = .black
        updateUIView(view, context: context)
        return view
    }

    func updateUIView(_ view: RemoteSceneSKView, context: Context) {
        let scene: RemoteDioramaScene
        if let existing = view.scene as? RemoteDioramaScene,
           existing.cacheKey == RemoteSceneFrameRenderer.cacheKey(for: theme) {
            scene = existing
        } else {
            (view.scene as? RemoteDioramaScene)?.setActive(false, reduceMotion: true)
            scene = RemoteDioramaScene(theme: theme, configuration: configuration, size: view.bounds.size)
            scene.scaleMode = .resizeFill
            view.presentScene(scene)
            Task { @MainActor [weak scene, weak view] in
                guard await RemoteSceneFrameRenderer.prepare(theme: theme),
                      let scene, let view, view.scene === scene,
                      let images = RemoteSceneFrameRenderer.images(for: theme) else { return }
                scene.setLayerImages(images)
                view.refreshStill()
            }
        }
        scene.configuration = configuration
        scene.setActive(active, reduceMotion: reduceMotion)
        view.sceneInteractionEnabled = active && !reduceMotion
        view.preferredFramesPerSecond = ProcessInfo.processInfo.isLowPowerModeEnabled ? 30 : 60
        view.isPaused = !active || reduceMotion
        if reduceMotion { scene.updateFrame(at: 0, displacement: .zero) }
        view.showsStill = !active || reduceMotion
        view.refreshStill()
    }

    static func dismantleUIView(_ view: RemoteSceneSKView, coordinator: ()) {
        (view.scene as? RemoteDioramaScene)?.setActive(false, reduceMotion: true)
        view.isPaused = true
        view.presentScene(nil)
    }
}

@MainActor
final class RemoteSceneSKView: SKView, UIGestureRecognizerDelegate {
    var showsStill = false
    private let still = UIImageView()
    private lazy var interactionPan = UIPanGestureRecognizer(target: self, action: #selector(handleInteractionPan(_:)))

    override init(frame: CGRect) {
        super.init(frame: frame)
        still.isUserInteractionEnabled = false
        still.contentMode = .scaleToFill
        addSubview(still)
        interactionPan.delegate = self
        interactionPan.cancelsTouchesInView = false
        interactionPan.delaysTouchesBegan = false
        interactionPan.delaysTouchesEnded = false
        addGestureRecognizer(interactionPan)
    }

    required init?(coder: NSCoder) { nil }

    var sceneInteractionEnabled: Bool {
        get { interactionPan.isEnabled }
        set { interactionPan.isEnabled = newValue }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === interactionPan else { return false }
        var ancestor = otherGestureRecognizer.view
        while let view = ancestor {
            if view is UIScrollView { return true }
            ancestor = view.superview
        }
        return false
    }

    @objc private func handleInteractionPan(_ recognizer: UIPanGestureRecognizer) {
        guard let scene = scene as? RemoteDioramaScene else { return }
        let location = recognizer.location(in: self)
        let scenePoint = CGPoint(x: location.x, y: bounds.height - location.y)
        switch recognizer.state {
        case .began, .changed:
            scene.trackExternalPan(at: scenePoint)
        case .ended:
            scene.finishExternalPan(at: scenePoint)
        case .cancelled, .failed:
            scene.cancelExternalPan()
        default:
            break
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        still.frame = bounds
        refreshStill()
    }

    func refreshStill() {
        still.isHidden = !showsStill
        guard showsStill, let scene = scene as? RemoteDioramaScene,
              bounds.width > 0, bounds.height > 0 else { return }
        scene.size = bounds.size
        guard let snapshot = texture(from: scene, crop: CGRect(origin: .zero, size: bounds.size)) else { return }
        still.image = UIImage(cgImage: snapshot.cgImage())
    }
}

private struct DecodedRemoteSceneImages: Sendable {
    let images: [String: UIImage]
}

private struct RemoteSceneAssetInput: Sendable {
    let name: String
    let fileURL: URL?
    let imageName: String?
}

@MainActor
enum RemoteSceneFrameRenderer {
    private static var prepared: (key: String, images: [String: UIImage])?
    private static var cachedScene: RemoteDioramaScene?
    private static var cachedView: SKView?

    static func cacheKey(for theme: Theme) -> String {
        "\(theme.id)-\(theme.remoteContentVersion ?? "bundled")"
    }

    static func prepare(theme: Theme) async -> Bool {
        guard let recipe = theme.remoteScene else { return false }
        let key = cacheKey(for: theme)
        if prepared?.key == key { return true }
        var assetInputs: [String: RemoteSceneAssetInput] = [:]
        for layer in recipe.layers where assetInputs[layer.asset] == nil {
            if let version = theme.remoteContentVersion {
                if let source = theme.remoteAssetURLs[layer.asset],
                   let localURL = await RemoteAssetCache.shared.imageURL(
                       source: source, contentVersion: version, itemID: theme.id, assetName: layer.asset
                   ) {
                    assetInputs[layer.asset] = RemoteSceneAssetInput(name: layer.asset, fileURL: localURL, imageName: nil)
                } else if layer.asset == "artwork", UIImage(named: theme.artwork) != nil {
                    assetInputs[layer.asset] = RemoteSceneAssetInput(name: layer.asset, fileURL: nil, imageName: theme.artwork)
                } else {
                    return false
                }
            } else {
                let imageName = layer.asset == "artwork" ? theme.artwork : layer.asset
                assetInputs[layer.asset] = RemoteSceneAssetInput(name: layer.asset, fileURL: nil, imageName: imageName)
            }
        }

        let decoded = await Task.detached(priority: .userInitiated) {
            var images: [String: UIImage] = [:]
            for input in assetInputs.values {
                let loaded = input.fileURL.flatMap { UIImage(contentsOfFile: $0.path) }
                    ?? input.imageName.flatMap { UIImage(named: $0) }
                guard let image = loaded?.preparingForDisplay() else {
                    return DecodedRemoteSceneImages(images: [:])
                }
                images[input.name] = image
            }
            return DecodedRemoteSceneImages(images: images)
        }.value
        guard recipe.layers.allSatisfy({ decoded.images[$0.asset] != nil }) else { return false }
        prepared = (key, decoded.images)
        return true
    }

    static func images(for theme: Theme) -> [String: UIImage]? {
        guard prepared?.key == cacheKey(for: theme) else { return nil }
        return prepared?.images
    }

    static func image(theme: Theme, configuration: SceneConfiguration, size: CGSize, time: TimeInterval) -> UIImage? {
        guard size.width > 0, size.height > 0, size.width <= 4096, size.height <= 4096,
              theme.remoteScene != nil,
              let prepared, prepared.key == cacheKey(for: theme) else { return nil }

        let scale = UIScreen.main.scale
        let logicalSize = CGSize(width: size.width / scale, height: size.height / scale)
        let key = cacheKey(for: theme)
        let scene: RemoteDioramaScene
        let renderer: SKView
        if let existing = cachedScene, let existingView = cachedView,
           existing.cacheKey == key, existing.size == logicalSize {
            scene = existing
            renderer = existingView
            scene.configuration = configuration
        } else {
            scene = RemoteDioramaScene(theme: theme, configuration: configuration, size: logicalSize)
            scene.setLayerImages(prepared.images)
            renderer = SKView(frame: CGRect(origin: .zero, size: logicalSize))
            renderer.contentScaleFactor = scale
            cachedScene = scene
            cachedView = renderer
        }
        scene.updateFrame(at: time, displacement: CGPoint(x: sin(time * 0.61) * 0.24, y: cos(time * 0.47) * 0.16))
        guard let texture = renderer.texture(from: scene, crop: CGRect(origin: .zero, size: logicalSize)) else { return nil }
        return UIImage(cgImage: texture.cgImage(), scale: 1, orientation: .up)
    }
}

@MainActor
final class RemoteDioramaScene: SKScene {
    let theme: Theme
    let cacheKey: String
    var configuration: SceneConfiguration
    private let recipe: RemoteSceneRecipe
    private var layerNodes: [(RemoteSceneLayer, SKSpriteNode)] = []
    private var particleNodes: [(RemoteParticleEmitter, Int, SKShapeNode)] = []
    private let touchRipple = SKShapeNode(circleOfRadius: 1)
    private let lightNode = SKSpriteNode()
    private let motion = CMMotionManager()
    private var elapsed: TimeInterval = 0
    private var lastTime: TimeInterval?
    private var finger = CGPoint.zero
    private var smoothed = CGPoint.zero
    private var touchPoint = CGPoint.zero
    private var tapTime: TimeInterval = -.infinity
    private var touching = false
    private var externalPanActive = false
    private var reduceMotion = false
    private var active = false

    init(theme: Theme, configuration: SceneConfiguration, size: CGSize) {
        self.theme = theme
        cacheKey = RemoteSceneFrameRenderer.cacheKey(for: theme)
        self.configuration = configuration
        recipe = theme.remoteScene ?? RemoteSceneRecipe(layers: [], particles: nil, light: nil, interaction: .none, ambientAudioAsset: nil)
        super.init(size: CGSize(width: max(size.width, 1), height: max(size.height, 1)))
        anchorPoint = .zero
        backgroundColor = UIColor(red: 0.025, green: 0.035, blue: 0.08, alpha: 1)
        isUserInteractionEnabled = true
        buildLayers()
        buildLight()
        buildParticles()
        touchRipple.strokeColor = UIColor.white.withAlphaComponent(0.85)
        touchRipple.fillColor = .clear
        touchRipple.lineWidth = max(1, size.width / 260)
        touchRipple.zPosition = 100
        touchRipple.isHidden = true
        addChild(touchRipple)
        updateFrame(at: 0, displacement: .zero)
    }

    required init?(coder: NSCoder) { nil }

    func setLayerImages(_ images: [String: UIImage]) {
        for (descriptor, node) in layerNodes {
            guard let image = images[descriptor.asset] else { continue }
            let texture = SKTexture(image: image)
            texture.filteringMode = theme.isPixel ? .nearest : .linear
            node.texture = texture
        }
        layoutLayers()
        updateFrame(at: reduceMotion ? 0 : elapsed, displacement: smoothed)
    }

    func setActive(_ value: Bool, reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
        active = value
        if value && !reduceMotion && motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = ProcessInfo.processInfo.isLowPowerModeEnabled ? 1 / 30 : 1 / 60
            if !motion.isDeviceMotionActive { motion.startDeviceMotionUpdates() }
        } else {
            motion.stopDeviceMotionUpdates()
            lastTime = nil
            touching = false
            externalPanActive = false
            finger = .zero
            smoothed = .zero
        }
    }

    override func willMove(from view: SKView) { motion.stopDeviceMotionUpdates() }

    override func didChangeSize(_ oldSize: CGSize) {
        layoutLayers()
        updateFrame(at: reduceMotion ? 0 : elapsed, displacement: smoothed)
    }

    override func update(_ currentTime: TimeInterval) {
        guard active && !reduceMotion else { return }
        let delta = min(max(currentTime - (lastTime ?? currentTime), 0), 0.05)
        lastTime = currentTime
        elapsed += delta
        let gravity = motion.deviceMotion?.gravity
        let target = touching ? finger : CGPoint(x: (gravity?.x ?? 0) * 0.9, y: (gravity?.y ?? 0) * 0.55)
        let smoothing = 1 - exp(-delta * 8)
        smoothed.x += (target.x - smoothed.x) * smoothing
        smoothed.y += (target.y - smoothed.y) * smoothing
        updateFrame(at: elapsed, displacement: smoothed)
        let rate = ProcessInfo.processInfo.isLowPowerModeEnabled ? 30 : 60
        if view?.preferredFramesPerSecond != rate { view?.preferredFramesPerSecond = rate }
    }

    func updateFrame(at time: TimeInterval, displacement: CGPoint) {
        let intensity = min(max(configuration.intensity, 0), 1)
        let depth = min(max(configuration.depth, 0), 1)
        let particleAmount = min(max(configuration.particles, 0), 1)
        for (layer, node) in layerNodes {
            let phase = time * (.pi * 2 / max(layer.period, 0.5))
            let parallax = layer.parallax * depth * intensity
            var x = size.width / 2 + displacement.x * size.width * 0.045 * parallax
            var y = size.height / 2 + displacement.y * size.height * 0.045 * parallax
            node.zRotation = 0
            node.alpha = 1
            switch layer.animation {
            case .still:
                break
            case .sway:
                node.zRotation = CGFloat(sin(phase) * layer.amount * 0.07 * intensity)
            case .drift:
                x += CGFloat(sin(phase) * layer.amount * 0.018) * size.width
                y += CGFloat(cos(phase * 0.7) * layer.amount * 0.01) * size.height
            case .flicker:
                node.alpha = 1 - layer.amount * 0.18 * (0.5 + 0.5 * sin(phase * 1.8))
            case .pulse:
                node.setScale(1 + layer.amount * 0.012 * sin(phase) * intensity)
            }
            if layer.animation != .pulse { node.setScale(1) }
            node.position = CGPoint(x: x, y: y)
        }

        for (emitterIndex, particle) in particleNodes.enumerated() {
            let (emitter, particleIndex, node) = particle
            node.isHidden = particleAmount < 0.01
            let seed = Double(particleIndex + 1 + emitterIndex * 37)
            let baseX = (seed * 0.618_033_988_75).truncatingRemainder(dividingBy: 1)
            let baseY = (seed * 0.381_966_011_25 + 0.17).truncatingRemainder(dividingBy: 1)
            let speed = (0.012 + emitter.speed * 0.045) * (0.35 + intensity)
            let travelsUp = [.ember, .smoke, .firefly, .bubble].contains(emitter.preset)
            let direction = travelsUp ? 1.0 : -1.0
            var x = baseX * size.width + displacement.x * size.width * 0.025 * intensity
            var y = wrapped(baseY + direction * time * speed * (0.5 + baseX)) * size.height
            let tapAge = time - tapTime
            if tapAge >= 0, tapAge < 1.1 {
                switch recipe.interaction {
                case .push:
                    let dx = x - touchPoint.x
                    let dy = y - touchPoint.y
                    let distance = max(hypot(dx, dy), 1)
                    let force = CGFloat((1.1 - tapAge) * 24 * Double(layerSafe(emitter.speed)))
                    x += dx / distance * force
                    y += dy / distance * force
                case .swirl:
                    let dx = x - touchPoint.x
                    let dy = y - touchPoint.y
                    let angle = CGFloat((1.1 - tapAge) * 1.4)
                    x = touchPoint.x + dx * cos(angle) - dy * sin(angle)
                    y = touchPoint.y + dx * sin(angle) + dy * cos(angle)
                case .emberBurst, .bubbleTrail:
                    if emitter.preset == .ember || emitter.preset == .bubble {
                        let angle = CGFloat(seed * 2.399_963)
                        let baseDistance = CGFloat(18 + (particleIndex % 28) * 2)
                        let ageDistance = CGFloat(tapAge + 0.2)
                        let distance = baseDistance * ageDistance
                        x = touchPoint.x + cos(angle) * distance
                        y = touchPoint.y + sin(angle) * distance + CGFloat(tapAge * 20)
                    }
                case .none, .ripple:
                    break
                }
            }
            node.position = CGPoint(x: x, y: y)
            node.alpha = CGFloat(particleAmount) * particleAlpha(preset: emitter.preset, time: time, seed: seed)
            node.setScale(max(0.75, size.width / 390))
            if emitter.preset == .ember || emitter.preset == .firefly || emitter.preset == .stardust {
                node.alpha *= CGFloat(0.58 + 0.42 * abs(sin(time * 2 + seed)))
            }
        }

        let rippleAge = time - tapTime
        if recipe.interaction == .ripple, rippleAge >= 0, rippleAge < 1.1 {
            touchRipple.isHidden = false
            touchRipple.position = touchPoint
            let progress = CGFloat(rippleAge / 1.1)
            touchRipple.setScale(1 + progress * size.width * 0.12)
            touchRipple.alpha = 1 - progress
        } else {
            touchRipple.isHidden = true
        }

        if let light = recipe.light {
            let phase = time * (.pi * 2 / max(light.period, 0.5))
            lightNode.isHidden = false
            lightNode.position = CGPoint(x: size.width * light.x, y: size.height * light.y)
            lightNode.setScale(max(1, size.width * light.radius / 2))
            lightNode.alpha = CGFloat(0.48 + 0.52 * (1 - light.flicker * (0.5 + 0.5 * sin(phase))))
        } else {
            lightNode.isHidden = true
        }
    }

    private func buildLayers() {
        for (index, layer) in recipe.layers.enumerated() {
            let node = SKSpriteNode()
            node.zPosition = CGFloat(index)
            node.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            addChild(node)
            layerNodes.append((layer, node))
        }
    }

    private func buildLight() {
        guard let light = recipe.light else { return }
        let hex = UInt32(light.color.dropFirst(), radix: 16) ?? 0xFF9A40
        lightNode.texture = Self.softLightTexture
        lightNode.size = CGSize(width: 2, height: 2)
        lightNode.color = UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                                  blue: CGFloat(hex & 0xFF) / 255, alpha: 0.28)
        lightNode.colorBlendFactor = 1
        lightNode.blendMode = .add
        lightNode.zPosition = CGFloat(recipe.layers.count + 5)
        addChild(lightNode)
    }

    private static let softLightTexture: SKTexture = {
        let size = CGSize(width: 128, height: 128)
        let renderer = UIGraphicsImageRenderer(size: size, format: UIGraphicsImageRendererFormat.default())
        let image = renderer.image { context in
            let colors = [
                UIColor.white.withAlphaComponent(0.9).cgColor,
                UIColor.white.withAlphaComponent(0.44).cgColor,
                UIColor.white.withAlphaComponent(0.06).cgColor,
                UIColor.white.withAlphaComponent(0).cgColor
            ] as CFArray
            let locations: [CGFloat] = [0, 0.34, 0.72, 1]
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colors, locations: locations) else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            context.cgContext.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                                 endCenter: center, endRadius: size.width / 2, options: [])
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }()

    private func layoutLayers() {
        for (layer, node) in layerNodes {
            node.size = CGSize(width: size.width * (1.05 + abs(layer.parallax) * 0.025),
                               height: size.height * (1.05 + abs(layer.parallax) * 0.025))
        }
    }

    private func buildParticles() {
        for (emitterIndex, emitter) in (recipe.particles ?? []).enumerated() {
            for index in 0..<emitter.count {
                let node: SKShapeNode
                switch emitter.preset {
                case .rain:
                    node = SKShapeNode(rectOf: CGSize(width: 1.2, height: CGFloat(10 + index % 8)))
                    node.zRotation = -0.12
                case .smoke:
                    node = SKShapeNode(circleOfRadius: CGFloat(3 + index % 6))
                case .bubble:
                    node = SKShapeNode(circleOfRadius: CGFloat(2 + index % 4))
                    node.fillColor = .clear
                    node.lineWidth = 1
                case .ember, .firefly, .snow, .stardust:
                    node = SKShapeNode(circleOfRadius: CGFloat(1 + index % 3))
                }
                node.fillColor = particleColor(emitter.preset)
                node.strokeColor = emitter.preset == .bubble ? UIColor(red: 0.55, green: 0.88, blue: 1, alpha: 0.75) : .clear
                node.glowWidth = [.ember, .firefly, .stardust].contains(emitter.preset) ? 2 : 0
                node.isAntialiased = !theme.isPixel
                node.zPosition = CGFloat(recipe.layers.count + 10 + emitterIndex)
                addChild(node)
                particleNodes.append((emitter, index, node))
            }
        }
    }

    private func particleColor(_ preset: RemoteParticlePreset) -> UIColor {
        switch preset {
        case .rain: UIColor(red: 0.60, green: 0.77, blue: 0.94, alpha: 0.48)
        case .ember: UIColor(red: 1, green: 0.42, blue: 0.10, alpha: 0.92)
        case .smoke: UIColor(red: 0.63, green: 0.68, blue: 0.76, alpha: 0.17)
        case .firefly: UIColor(red: 0.84, green: 0.95, blue: 0.44, alpha: 0.95)
        case .snow: UIColor(white: 0.92, alpha: 0.82)
        case .bubble: UIColor(red: 0.55, green: 0.88, blue: 1, alpha: 0.35)
        case .stardust: UIColor(red: 0.76, green: 0.85, blue: 1, alpha: 0.9)
        }
    }

    private func particleAlpha(preset: RemoteParticlePreset, time: TimeInterval, seed: Double) -> CGFloat {
        let flicker = 0.55 + 0.45 * abs(sin(time * (0.8 + seed * 0.025) + seed))
        return switch preset {
        case .rain: 0.65
        case .smoke: 0.32 + 0.15 * flicker
        case .snow, .bubble: 0.68
        case .ember, .firefly, .stardust: flicker
        }
    }

    private func track(_ point: CGPoint) {
        guard active, !reduceMotion else { return }
        touching = true
        finger = CGPoint(x: (point.x / max(size.width, 1) - 0.5) * 2,
                         y: (point.y / max(size.height, 1) - 0.5) * 2)
        touchPoint = point
    }

    private func track(_ touches: Set<UITouch>) {
        guard let point = touches.first?.location(in: self) else { return }
        track(point)
    }

    func trackExternalPan(at point: CGPoint) {
        guard active, !reduceMotion else { return }
        externalPanActive = true
        track(point)
    }

    func finishExternalPan(at point: CGPoint) {
        guard active, !reduceMotion else {
            cancelExternalPan()
            return
        }
        track(point)
        externalPanActive = false
        touching = false
        tapTime = elapsed
    }

    func cancelExternalPan() {
        externalPanActive = false
        touching = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { track(touches) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { track(touches) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard active, !reduceMotion else {
            touching = false
            return
        }
        if let point = touches.first?.location(in: self) {
            touchPoint = point
            tapTime = elapsed
        }
        if !externalPanActive { touching = false }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !externalPanActive { touching = false }
    }

    private func wrapped(_ value: Double) -> CGFloat {
        CGFloat((value.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1))
    }

    private func layerSafe(_ value: Double) -> CGFloat { CGFloat(min(max(value, 0), 1)) }
}
