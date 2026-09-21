import CoreMotion
import SpriteKit
import SwiftUI

struct PixelSceneSurface: UIViewRepresentable {
    let theme: Theme
    let configuration: SceneConfiguration
    let active: Bool
    let reduceMotion: Bool

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.ignoresSiblingOrder = true
        view.isOpaque = true
        view.backgroundColor = .black
        updateUIView(view, context: context)
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {
        let scene: PixelThemeScene
        if let existing = view.scene as? PixelThemeScene, existing.theme.id == theme.id {
            scene = existing
        } else {
            (view.scene as? PixelThemeScene)?.setActive(false, reduceMotion: true)
            scene = PixelThemeScene(theme: theme, configuration: configuration, size: view.bounds.size, showsHUD: true)
            scene.scaleMode = .resizeFill
            view.presentScene(scene)
            Task { @MainActor [weak scene, weak view] in
                guard let image = await PixelThemeArtwork.load(theme),
                      let scene, let view, view.scene === scene else { return }
                scene.setBackground(image)
            }
        }
        scene.configuration = configuration
        scene.setActive(active, reduceMotion: reduceMotion)
        view.preferredFramesPerSecond = ProcessInfo.processInfo.isLowPowerModeEnabled ? 30 : 60
        view.isPaused = !active || reduceMotion
        if reduceMotion { scene.renderFrame(time: 0, input: .idle) }
    }

    static func dismantleUIView(_ view: SKView, coordinator: ()) {
        (view.scene as? PixelThemeScene)?.setActive(false, reduceMotion: true)
        view.isPaused = true
        view.presentScene(nil)
    }
}

@MainActor
enum PixelFrameRenderer {
    private static var preparedArtwork: (name: String, image: UIImage)?
    private static var cachedScene: PixelThemeScene?
    private static var cachedView: SKView?

    static func prepare(theme: Theme) async -> Bool {
        if theme.interaction == .fish || theme.interaction == .nature { return true }
        if preparedArtwork?.name == theme.artwork { return true }
        guard let image = await PixelThemeArtwork.load(theme) else { return false }
        preparedArtwork = (theme.artwork, image)
        return true
    }

    static func image(theme: Theme, configuration: SceneConfiguration, size: CGSize, time: TimeInterval) -> UIImage? {
        guard size.width > 0, size.height > 0, size.width <= 4096, size.height <= 4096 else { return nil }
        let scale = UIScreen.main.scale
        let logicalSize = CGSize(width: size.width / scale, height: size.height / scale)
        let scene: PixelThemeScene
        let view: SKView
        if let existing = cachedScene, let existingView = cachedView,
           existing.theme.id == theme.id, existing.size == logicalSize {
            scene = existing
            view = existingView
            scene.configuration = configuration
        } else {
            scene = PixelThemeScene(theme: theme, configuration: configuration, size: logicalSize, showsHUD: false)
            if preparedArtwork?.name == theme.artwork { scene.setBackground(preparedArtwork?.image) }
            view = SKView(frame: CGRect(origin: .zero, size: logicalSize))
            view.contentScaleFactor = scale
            view.presentScene(scene)
            cachedScene = scene
            cachedView = view
        }
        let input = InteractiveSceneBehavior.Input(
            tilt: .init(x: sin(time * 0.8) * 0.65, y: cos(time * 0.55) * 0.25),
            tap: time > 1.25 && time < 1.3 ? .init(x: 0.35, y: 0.1) : nil
        )
        scene.renderFrame(time: time, input: input)
        guard let texture = view.texture(from: scene, crop: CGRect(origin: .zero, size: logicalSize)) else { return nil }
        return UIImage(cgImage: texture.cgImage(), scale: 1, orientation: .up)
    }
}

@MainActor
final class PixelThemeScene: SKScene {
    let theme: Theme
    var configuration: SceneConfiguration {
        didSet { refreshBehaviorModeIfNeeded() }
    }

    private let showsHUD: Bool
    private let motion = CMMotionManager()
    private let background = SKSpriteNode()
    private let scenery = SKNode()
    private let player = SKNode()
    private let score = SKLabelNode(fontNamed: "Menlo-Bold")
    private var obstacleNodes: [UInt64: SKShapeNode] = [:]
    private var behavior: InteractiveSceneBehavior
    private var elapsed: TimeInterval = 0
    private var lastTime: TimeInterval?
    private var finger = InteractiveSceneBehavior.Vector.zero
    private var touching = false
    private var tapPending: InteractiveSceneBehavior.Vector?
    private var reduceMotion = false
    private var active = false

    init(theme: Theme, configuration: SceneConfiguration, size: CGSize, showsHUD: Bool) {
        self.theme = theme
        self.configuration = configuration
        self.showsHUD = showsHUD
        let profile = theme.interaction ?? .nature
        let mode: InteractiveSceneBehavior.Mode = configuration.scoreMode ? .score : .calm
        let highScore = UserDefaults.standard.integer(forKey: "pixel-high-score.\(theme.id)")
        behavior = InteractiveSceneBehavior(profile: profile, mode: mode, seed: Self.seed(for: theme.id), highScore: highScore)
        super.init(size: CGSize(width: max(size.width, 1), height: max(size.height, 1)))
        backgroundColor = UIColor(red: 0.025, green: 0.035, blue: 0.08, alpha: 1)
        anchorPoint = .zero
        buildScene()
        renderFrame(time: 0, input: .idle)
    }

    required init?(coder: NSCoder) { nil }

    override func didChangeSize(_ oldSize: CGSize) {
        layoutBackground()
        layoutScenery()
        renderFrame(time: reduceMotion ? 0 : elapsed, input: .idle)
    }

    func setBackground(_ image: UIImage?) {
        guard let image else { return }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        background.texture = texture
        layoutBackground()
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
            tapPending = nil
        }
    }

    override func willMove(from view: SKView) { motion.stopDeviceMotionUpdates() }

    override func update(_ currentTime: TimeInterval) {
        guard active && !reduceMotion else { return }
        let delta = min(max(currentTime - (lastTime ?? currentTime), 0), 0.05)
        lastTime = currentTime
        elapsed += delta
        let gravity = motion.deviceMotion?.gravity
        let tilt = InteractiveSceneBehavior.Vector(x: (gravity?.x ?? 0) * 1.2, y: (gravity?.y ?? 0) * 0.8)
        let input = InteractiveSceneBehavior.Input(
            tilt: tilt,
            drag: touching ? finger : nil,
            tap: tapPending
        )
        tapPending = nil
        let events = behavior.update(deltaTime: delta, time: elapsed, input: input)
        apply(events: events)
        syncNodes()
    }

    func renderFrame(time: TimeInterval, input: InteractiveSceneBehavior.Input) {
        refreshBehaviorModeIfNeeded()
        if time <= elapsed {
            behavior = InteractiveSceneBehavior(
                profile: theme.interaction ?? .nature,
                mode: configuration.scoreMode ? .score : .calm,
                seed: Self.seed(for: theme.id),
                highScore: 0
            )
            elapsed = 0
        }
        let delta = max(0, min(time - elapsed, 1 / 30))
        elapsed = max(elapsed, time)
        let events = behavior.update(deltaTime: delta, time: time, input: input)
        apply(events: events)
        syncNodes()
    }

    private func buildScene() {
        background.zPosition = -20
        addChild(background)
        scenery.zPosition = -10
        addChild(scenery)
        if theme.interaction == .fish || theme.interaction == .nature { buildProgrammaticBackdrop() }
        buildPlayer()
        score.fontSize = 18
        score.horizontalAlignmentMode = .right
        score.verticalAlignmentMode = .top
        score.fontColor = UIColor(red: 0.76, green: 0.98, blue: 0.42, alpha: 1)
        score.zPosition = 30
        score.isHidden = !showsHUD || !configuration.scoreMode || theme.interaction?.supportsScoreMode != true
        addChild(score)
        layoutBackground()
        layoutScenery()
    }

    private func buildProgrammaticBackdrop() {
        let palette: [UIColor]
        if theme.interaction == .fish {
            palette = [.init(red: 0.02, green: 0.12, blue: 0.25, alpha: 1), .init(red: 0.02, green: 0.35, blue: 0.4, alpha: 0.85), .init(red: 0.45, green: 0.2, blue: 0.55, alpha: 0.9)]
        } else {
            palette = [.init(red: 0.02, green: 0.08, blue: 0.06, alpha: 1), .init(red: 0.08, green: 0.24, blue: 0.16, alpha: 0.9), .init(red: 0.38, green: 0.58, blue: 0.2, alpha: 0.8)]
        }
        for index in 0..<42 {
            let block = SKShapeNode(rectOf: CGSize(width: 10 + index % 5 * 5, height: 8 + index % 4 * 4), cornerRadius: 0)
            block.fillColor = palette[index % palette.count]
            block.strokeColor = .clear
            block.isAntialiased = false
            block.name = "backdrop-\(index)"
            scenery.addChild(block)
        }
    }

    private func buildPlayer() {
        let outline = UIColor(red: 0.76, green: 0.98, blue: 0.42, alpha: 1)
        let body: SKShapeNode
        switch theme.interaction ?? .nature {
        case .car:
            body = SKShapeNode(rectOf: CGSize(width: 40, height: 64), cornerRadius: 5)
        case .motorcycle:
            body = SKShapeNode(rectOf: CGSize(width: 20, height: 58), cornerRadius: 4)
        case .helicopter:
            body = SKShapeNode(ellipseOf: CGSize(width: 62, height: 28))
            let rotor = SKShapeNode(rectOf: CGSize(width: 92, height: 3))
            rotor.fillColor = outline
            rotor.strokeColor = .clear
            rotor.position.y = 20
            player.addChild(rotor)
        case .spaceship:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 38)); path.addLine(to: CGPoint(x: -25, y: -28)); path.addLine(to: CGPoint(x: 0, y: -18)); path.addLine(to: CGPoint(x: 25, y: -28)); path.closeSubpath()
            body = SKShapeNode(path: path)
        case .fish:
            body = SKShapeNode(ellipseOf: CGSize(width: 58, height: 30))
            let tail = SKShapeNode(rectOf: CGSize(width: 20, height: 20))
            tail.zRotation = .pi / 4
            tail.position.x = -34
            tail.fillColor = outline
            tail.strokeColor = .clear
            player.addChild(tail)
        case .nature:
            body = SKShapeNode(ellipseOf: CGSize(width: 16, height: 16))
        }
        body.fillColor = outline
        body.strokeColor = UIColor.black.withAlphaComponent(0.75)
        body.lineWidth = 4
        body.isAntialiased = false
        player.addChild(body)
        player.zPosition = 10
        addChild(player)
    }

    private func layoutBackground() {
        guard let texture = background.texture else { return }
        let source = texture.size()
        let scale = max(size.width / max(source.width, 1), size.height / max(source.height, 1))
        background.size = CGSize(width: source.width * scale, height: source.height * scale)
        background.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    private func layoutScenery() {
        for (index, node) in scenery.children.enumerated() {
            let edge = index.isMultiple(of: 2) ? 0.08 : 0.92
            let x = size.width * (edge + Double((index * 37) % 14) / 100)
            let y = size.height * (0.05 + Double((index * 61) % 90) / 100)
            node.position = CGPoint(x: x, y: y)
        }
        score.position = CGPoint(x: size.width - 18, y: size.height - 18)
    }

    private func syncNodes() {
        let state = behavior.state
        player.position = CGPoint(x: size.width * (0.5 + state.position.x * 0.34), y: size.height * (0.5 + state.position.y * 0.38))
        player.zRotation = state.rotation
        player.setScale(1 + state.tapResponse * 0.12)
        score.text = "\(state.score)  ·  \(state.highScore)"
        score.isHidden = !showsHUD || !behavior.isScoreActive

        let activeIDs = Set(behavior.obstacles.map(\.id))
        let staleIDs = obstacleNodes.keys.filter { !activeIDs.contains($0) }
        for id in staleIDs {
            obstacleNodes[id]?.removeFromParent()
            obstacleNodes[id] = nil
        }
        for obstacle in behavior.obstacles {
            let node = obstacleNodes[obstacle.id] ?? makeObstacle(id: obstacle.id)
            node.position = CGPoint(x: size.width * (0.5 + obstacle.position.x * 0.34), y: size.height * (0.5 + obstacle.position.y * 0.38))
            node.isHidden = !behavior.isScoreActive
        }

        background.position.x = size.width / 2 - state.position.x * size.width * 0.015 * configuration.depth
        background.position.y = size.height / 2 - state.position.y * size.height * 0.01 * configuration.depth
        scenery.children.enumerated().forEach { index, node in
            node.alpha = 0.22 + configuration.particles * 0.55
            node.zRotation = theme.interaction == .nature ? sin(elapsed + Double(index)) * 0.04 : 0
        }
    }

    private func makeObstacle(id: UInt64) -> SKShapeNode {
        let node = SKShapeNode(rectOf: CGSize(width: 24, height: 24), cornerRadius: 2)
        node.fillColor = UIColor(red: 0.92, green: 0.32, blue: 0.42, alpha: 0.95)
        node.strokeColor = .black
        node.lineWidth = 3
        node.isAntialiased = false
        node.zRotation = .pi / 4
        node.zPosition = 5
        obstacleNodes[id] = node
        addChild(node)
        return node
    }

    private func apply(events: [InteractiveSceneBehavior.Event]) {
        for event in events {
            if case let .highScoreChanged(value) = event {
                UserDefaults.standard.set(value, forKey: "pixel-high-score.\(theme.id)")
            }
        }
    }

    private func refreshBehaviorModeIfNeeded() {
        let requested: InteractiveSceneBehavior.Mode = configuration.scoreMode ? .score : .calm
        guard behavior.mode != requested else { return }
        behavior = InteractiveSceneBehavior(
            profile: theme.interaction ?? .nature,
            mode: requested,
            seed: Self.seed(for: theme.id),
            highScore: behavior.state.highScore
        )
    }

    private func track(_ touches: Set<UITouch>) {
        guard active && !reduceMotion, let point = touches.first?.location(in: self) else { return }
        touching = true
        finger = .init(x: (point.x / max(size.width, 1) - 0.5) * 2, y: (point.y / max(size.height, 1) - 0.5) * 2)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { track(touches) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { track(touches) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let point = touches.first?.location(in: self) {
            tapPending = .init(x: (point.x / max(size.width, 1) - 0.5) * 2, y: (point.y / max(size.height, 1) - 0.5) * 2)
        }
        touching = false
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { touching = false }

    private static func seed(for value: String) -> UInt64 {
        value.utf8.reduce(1_469_598_103_934_665_603) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
    }
}

enum PixelThemeArtwork {
    static func load(_ theme: Theme) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            if let artworkURL = theme.artworkURL,
               let image = UIImage(contentsOfFile: artworkURL.path) {
                return image.preparingForDisplay()
            }
            return UIImage(named: theme.artwork)?.preparingForDisplay()
        }.value
    }
}
