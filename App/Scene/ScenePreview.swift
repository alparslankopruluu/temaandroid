import SwiftUI
import SpriteKit
import CoreMotion

/// Decorative artwork surface. The enclosing screen owns accessible descriptions and controls.
struct ScenePreview: View {
    let theme: Theme
    var configuration: SceneConfiguration
    var isActive: Bool = true
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SceneSurface(theme: theme, configuration: configuration,
                     active: isActive && scenePhase == .active, reduceMotion: reduceMotion)
            .accessibilityHidden(true)
    }
}

private struct SceneSurface: UIViewRepresentable {
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
        let scene: ArtworkScene
        if let existing = view.scene as? ArtworkScene, existing.theme == theme {
            scene = existing
        } else {
            (view.scene as? ArtworkScene)?.setActive(false, reduceMotion: true)
            scene = ArtworkScene(theme: theme, configuration: configuration, size: view.bounds.size)
            scene.scaleMode = .resizeFill
            view.presentScene(scene)
        }
        scene.configuration = configuration
        scene.setActive(active, reduceMotion: reduceMotion)
        view.preferredFramesPerSecond = ProcessInfo.processInfo.isLowPowerModeEnabled ? 30 : 60
        view.isPaused = !active || reduceMotion
        if reduceMotion { scene.updateFrame(at: 0, displacement: .zero) }
    }

    static func dismantleUIView(_ view: SKView, coordinator: ()) {
        (view.scene as? ArtworkScene)?.setActive(false, reduceMotion: true)
        view.isPaused = true
        view.presentScene(nil)
    }
}

@MainActor
enum SceneFrameRenderer {
    private static var cachedScene: ArtworkScene?
    private static var cachedView: SKView?
    /// Renders only artwork, never the simulated clock, controls, or status bar.
    static func image(theme: Theme, configuration: SceneConfiguration, size: CGSize, time: TimeInterval) -> UIImage? {
        guard size.width > 0, size.height > 0, size.width <= 4096, size.height <= 4096 else { return nil }
        let scene: ArtworkScene
        let renderer: SKView
        if let previous = cachedScene, let previousView = cachedView, previous.theme == theme, previous.size == size {
            scene = previous
            renderer = previousView
            scene.configuration = configuration
        } else {
            scene = ArtworkScene(theme: theme, configuration: configuration, size: size)
            renderer = SKView(frame: CGRect(origin: .zero, size: size))
            renderer.contentScaleFactor = 1
            cachedScene = scene
            cachedView = renderer
        }
        scene.updateFrame(at: time, displacement: CGPoint(x: sin(time * 0.7) * 0.3, y: cos(time * 0.5) * 0.2))
        guard let texture = renderer.texture(from: scene, crop: CGRect(origin: .zero, size: size)) else { return nil }
        return UIImage(cgImage: texture.cgImage(), scale: 1, orientation: .up)
    }
}

/// One deterministic frame function drives both SpriteKit's clock and video/photo export.
@MainActor
private final class ArtworkScene: SKScene {
    let theme: Theme
    var configuration: SceneConfiguration
    private let artwork = SKSpriteNode()
    private let tint = SKSpriteNode(color: .clear, size: .zero)
    private let motion = CMMotionManager()
    private var particles: [SKShapeNode] = []
    private var finger = CGPoint.zero
    private var smoothed = CGPoint.zero
    private var touching = false
    private var reduceMotion = false
    private var active = false
    private var lastTime: TimeInterval?
    private var elapsed: TimeInterval = 0

    init(theme: Theme, configuration: SceneConfiguration, size: CGSize) {
        self.theme = theme
        self.configuration = configuration
        super.init(size: CGSize(width: max(size.width, 1), height: max(size.height, 1)))
        backgroundColor = .black
        anchorPoint = .zero
        if let image = Self.artworkImage(theme.artwork) { artwork.texture = SKTexture(image: image) }
        artwork.zPosition = 0
        addChild(artwork)
        tint.zPosition = 1
        tint.blendMode = .alpha
        addChild(tint)
        for index in 0..<28 {
            let radius: CGFloat = theme.collection == .ocean ? 1.8 : 1
            let particle = SKShapeNode(circleOfRadius: radius)
            particle.fillColor = theme.collection == .vehicles ? UIColor(white: 0.9, alpha: 1) : .white
            particle.strokeColor = .clear
            particle.glowWidth = theme.collection == .cosmos ? 2 : 0.6
            particle.zPosition = 2
            particle.name = String(index)
            addChild(particle)
            particles.append(particle)
        }
        updateFrame(at: 0, displacement: .zero)
    }

    required init?(coder aDecoder: NSCoder) { nil }

    private static func artworkImage(_ name: String) -> UIImage? {
        if let asset = UIImage(named: name) { return asset }
        for ext in ["jpg", "png", "jpeg"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext),
               let image = UIImage(contentsOfFile: url.path) { return image }
        }
        return nil
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
            finger = .zero
            smoothed = .zero
        }
    }

    override func willMove(from view: SKView) {
        motion.stopDeviceMotionUpdates()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        updateFrame(at: reduceMotion ? 0 : elapsed, displacement: smoothed)
    }

    override func update(_ currentTime: TimeInterval) {
        guard active && !reduceMotion else { return }
        let delta = min(max(currentTime - (lastTime ?? currentTime), 0), 0.05)
        lastTime = currentTime
        elapsed += delta
        let gravity = motion.deviceMotion?.gravity
        let sensor = CGPoint(x: (gravity?.x ?? 0) * 0.8, y: (gravity?.y ?? 0) * 0.35)
        let target = touching ? finger : sensor
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
        let zoom = min(max(configuration.zoom, 1), 1.8)
        let source = artwork.texture?.size() ?? size
        let factor = max(size.width / max(source.width, 1), size.height / max(source.height, 1)) * (1.08 + depth * 0.04) * zoom
        artwork.size = CGSize(width: source.width * factor, height: source.height * factor)
        let breathing = sin(time * 0.35) * 0.004 * intensity
        artwork.setScale(1 + breathing)
        artwork.position = CGPoint(x: size.width / 2 + displacement.x * size.width * 0.025 * depth,
                                   y: size.height / 2 + displacement.y * size.height * 0.025 * depth)
        tint.position = CGPoint(x: size.width / 2, y: size.height / 2)
        tint.size = size
        switch configuration.style {
        case 1: tint.color = UIColor(red: 0.03, green: 0.16, blue: 0.34, alpha: 0.22)
        case 2: tint.color = UIColor(red: 0.4, green: 0.17, blue: 0.04, alpha: 0.18)
        default: tint.color = .clear
        }
        for (index, particle) in particles.enumerated() {
            let seed = Double(index)
            let x = (seed * 0.61803398875).truncatingRemainder(dividingBy: 1)
            let y = (seed * 0.38196601125 + 0.17).truncatingRemainder(dividingBy: 1)
            let speed = (theme.collection == .vehicles ? 0.06 : 0.012) * intensity
            let animatedY = (y + time * speed * (0.4 + x)).truncatingRemainder(dividingBy: 1)
            particle.position = CGPoint(x: x * size.width + sin(time * 0.3 + seed) * 5 * intensity + displacement.x * 18 * depth,
                                        y: animatedY * size.height + displacement.y * 26 * depth)
            particle.alpha = min(max(configuration.particles, 0), 1) * (0.08 + 0.16 * abs(sin(time * 0.8 + seed)))
            particle.setScale(max(0.8, size.width / 390))
        }
    }

    private func track(_ touches: Set<UITouch>) {
        guard !reduceMotion, let point = touches.first?.location(in: self) else { return }
        touching = true
        finger = CGPoint(x: (point.x / max(size.width, 1) - 0.5) * 2,
                         y: (point.y / max(size.height, 1) - 0.5) * 2)
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { track(touches) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { track(touches) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { touching = false }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { touching = false }
}
