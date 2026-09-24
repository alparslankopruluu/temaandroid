import Foundation

/// A pure, renderer-independent interaction model for inline themes.
/// All coordinates are normalized to `-1...1`; callers own gesture and motion sampling.
struct InteractiveSceneBehavior: Equatable, Sendable {
    enum Profile: String, CaseIterable, Codable, Sendable {
        case car
        case motorcycle
        case helicopter
        case spaceship
        case fish
        case nature
        case ufo
        case aquarium
        case autumn
        case race
        case koi
        case snow

        var supportsScoreMode: Bool {
            switch self {
            case .car, .motorcycle, .helicopter, .spaceship, .ufo, .race: true
            case .fish, .nature, .aquarium, .autumn, .koi, .snow: false
            }
        }
    }

    enum Mode: String, Codable, Sendable {
        case calm
        case score
    }

    struct Vector: Equatable, Sendable {
        var x: Double
        var y: Double

        init(x: Double, y: Double) {
            self.x = x.clamped(to: -1...1)
            self.y = y.clamped(to: -1...1)
        }

        static let zero = Vector(x: 0, y: 0)

        fileprivate static func +(lhs: Self, rhs: Self) -> Self {
            Vector(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
        }

        fileprivate static func -(lhs: Self, rhs: Self) -> Self {
            Vector(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
        }

        fileprivate static func *(lhs: Self, rhs: Double) -> Self {
            Vector(unclampedX: lhs.x * rhs, y: lhs.y * rhs)
        }

        fileprivate init(unclampedX x: Double, y: Double) {
            self.x = x
            self.y = y
        }

        fileprivate var magnitude: Double { sqrt(x * x + y * y) }

        fileprivate var normalized: Self {
            let length = magnitude
            guard length > 0.000_001 else { return .zero }
            return Vector(unclampedX: x / length, y: y / length)
        }

        fileprivate func bounded() -> Self {
            Vector(x: x, y: y)
        }
    }

    struct Input: Equatable, Sendable {
        var tilt: Vector
        var drag: Vector?
        var tap: Vector?

        init(tilt: Vector = .zero, drag: Vector? = nil, tap: Vector? = nil) {
            self.tilt = tilt
            self.drag = drag
            self.tap = tap
        }

        static let idle = Input()

        fileprivate var directional: Vector { drag ?? tilt }
    }

    struct Obstacle: Equatable, Identifiable, Sendable {
        let id: UInt64
        var position: Vector
        let radius: Double
    }

    struct State: Equatable, Sendable {
        fileprivate(set) var position: Vector
        fileprivate(set) var velocity: Vector
        fileprivate(set) var rotation: Double
        fileprivate(set) var tapResponse: Double
        fileprivate(set) var score: Int
        fileprivate(set) var highScore: Int
        fileprivate(set) var elapsed: TimeInterval
        fileprivate(set) var run: UInt64
    }

    enum ResetReason: Equatable, Sendable {
        case collision(obstacleID: UInt64)
    }

    enum Event: Equatable, Sendable {
        case tapResponded(profile: Profile)
        case scoreChanged(Int)
        case highScoreChanged(Int)
        case collision(obstacleID: UInt64)
        case reset(ResetReason)
    }

    private(set) var profile: Profile
    private(set) var mode: Mode
    private(set) var state: State
    private(set) var obstacles: [Obstacle]

    private let seed: UInt64
    private var random: SeededGenerator
    private var scoreDistance: Double = 0

    var isScoreActive: Bool { mode == .score && profile.supportsScoreMode }

    init(profile: Profile, mode: Mode = .calm, seed: UInt64, highScore: Int = 0) {
        self.profile = profile
        self.mode = mode
        self.seed = seed
        let initial = Self.initialPosition(for: profile)
        state = State(
            position: initial,
            velocity: .zero,
            rotation: 0,
            tapResponse: 0,
            score: 0,
            highScore: max(0, highScore),
            elapsed: 0,
            run: 0
        )
        random = SeededGenerator(seed: seed)
        obstacles = []
        obstacles = makeObstacles(count: 6)
    }

    /// Advances one deterministic frame. `time` is an explicit monotonic scene time used
    /// only for repeatable ambient movement; score and physics advance by `deltaTime`.
    @discardableResult
    mutating func update(
        deltaTime: TimeInterval,
        time: TimeInterval,
        input: Input = .idle
    ) -> [Event] {
        let delta = deltaTime.clamped(to: 0...0.1)
        state.elapsed += delta
        state.tapResponse = max(0, state.tapResponse - delta * 2.4)

        var events: [Event] = []
        apply(input: input, deltaTime: delta, time: time, events: &events)
        state.position = (state.position + state.velocity * delta).bounded()

        guard isScoreActive else {
            state.score = 0
            return events
        }

        let previousScore = state.score
        scoreDistance += delta * forwardSpeed
        state.score = Int(scoreDistance * 10)
        if state.score != previousScore {
            events.append(.scoreChanged(state.score))
        }

        advanceObstacles(deltaTime: delta)
        if let obstacle = obstacles.first(where: collides(with:)) {
            events.append(.collision(obstacleID: obstacle.id))
            if state.score > state.highScore {
                state.highScore = state.score
                events.append(.highScoreChanged(state.highScore))
            }
            reset(after: obstacle.id)
            events.append(.reset(.collision(obstacleID: obstacle.id)))
        }

        return events
    }

    private mutating func apply(
        input: Input,
        deltaTime: TimeInterval,
        time: TimeInterval,
        events: inout [Event]
    ) {
        let direction = input.directional
        let response = min(1, deltaTime * responsiveness)

        switch profile {
        case .car, .race:
            state.velocity.x += (direction.x * 1.25 - state.velocity.x) * response
            state.velocity.y = 0
            state.position.y = -0.68
            state.rotation = direction.x * 0.08
        case .motorcycle:
            state.velocity.x += (direction.x * 1.4 - state.velocity.x) * response
            state.velocity.y = 0
            state.position.y = -0.68
            state.rotation = direction.x * 0.28
        case .helicopter:
            state.velocity.x += (direction.x * 0.95 - state.velocity.x) * response
            state.velocity.y += (direction.y * 0.8 - state.velocity.y) * response
            state.rotation = direction.x * 0.18
            if input.tap != nil { state.velocity.y = min(1, state.velocity.y + 0.55) }
        case .spaceship, .ufo:
            state.velocity.x += (direction.x * 1.05 - state.velocity.x) * response
            state.velocity.y += (direction.y * 0.7 - state.velocity.y) * response
            state.rotation = direction.x * 0.22
            if input.tap != nil { state.velocity.y = min(1, state.velocity.y + 0.38) }
        case .fish, .aquarium, .koi:
            let ambient = Vector(unclampedX: sin(time * 0.7) * 0.16, y: cos(time * 0.45) * 0.08)
            let target = direction * 0.45 + ambient
            state.velocity.x += (target.x - state.velocity.x) * response
            state.velocity.y += (target.y - state.velocity.y) * response
            if let tap = input.tap {
                let away = (state.position - tap).normalized
                state.velocity = (state.velocity + away * 0.65).bounded()
            }
            state.rotation = state.velocity.y * 0.12
        case .nature, .autumn, .snow:
            let breeze = Vector(unclampedX: sin(time * (profile == .snow ? 0.28 : 0.8)) * 0.08,
                                y: cos(time * 0.35) * 0.04)
            let target = direction * (profile == .autumn ? 0.3 : 0.16) + breeze
            state.velocity.x += (target.x - state.velocity.x) * response
            state.velocity.y += (target.y - state.velocity.y) * response
            state.rotation = sin(time * 0.8) * 0.025 + direction.x * 0.035
        }

        if input.tap != nil {
            state.tapResponse = 1
            events.append(.tapResponded(profile: profile))
        }
    }

    private mutating func advanceObstacles(deltaTime: TimeInterval) {
        for index in obstacles.indices {
            var position = obstacles[index].position
            position = Vector(unclampedX: position.x, y: position.y - forwardSpeed * deltaTime)
            if position.y < -1.25 {
                position = Vector(
                    unclampedX: laneValue(),
                    y: highestObstacleY + nextSpacing()
                )
            }
            obstacles[index].position = position
        }
    }

    private func collides(with obstacle: Obstacle) -> Bool {
        let offset = state.position - obstacle.position
        return abs(offset.x) <= obstacle.radius + playerRadius
            && abs(offset.y) <= obstacle.radius + playerRadius
    }

    private mutating func reset(after obstacleID: UInt64) {
        state.position = Self.initialPosition(for: profile)
        state.velocity = .zero
        state.rotation = 0
        state.tapResponse = 0
        state.score = 0
        state.elapsed = 0
        state.run &+= 1
        scoreDistance = 0
        random = SeededGenerator(seed: seed &+ state.run &* 0x9E37_79B9_7F4A_7C15)
        obstacles = makeObstacles(count: 6, idOffset: (state.run &+ 1) * 1_000)
        _ = obstacleID
    }

    private mutating func makeObstacles(count: Int, idOffset: UInt64 = 0) -> [Obstacle] {
        var y = 0.35
        return (0..<count).map { index in
            y += nextSpacing()
            return Obstacle(
                id: idOffset + UInt64(index),
                position: Vector(unclampedX: laneValue(), y: y),
                radius: profile == .motorcycle ? 0.1 : 0.13
            )
        }
    }

    private mutating func laneValue() -> Double {
        let lanes = [-0.62, 0.0, 0.62]
        return lanes[random.nextIndex(upperBound: lanes.count)]
    }

    private mutating func nextSpacing() -> Double {
        0.62 + random.nextUnit() * 0.42
    }

    private var highestObstacleY: Double {
        obstacles.map(\.position.y).max() ?? 0.5
    }

    private var forwardSpeed: Double {
        switch profile {
        case .car, .race: 0.78
        case .motorcycle: 0.86
        case .helicopter: 0.66
        case .spaceship, .ufo: 0.74
        case .fish, .nature, .aquarium, .autumn, .koi, .snow: 0
        }
    }

    private var responsiveness: Double {
        switch profile {
        case .car, .race: 8
        case .motorcycle: 10
        case .helicopter, .spaceship, .ufo: 7
        case .fish, .aquarium, .koi: 5
        case .nature, .autumn, .snow: 3
        }
    }

    private var playerRadius: Double {
        switch profile {
        case .motorcycle: 0.08
        case .car, .helicopter, .spaceship, .ufo, .race: 0.11
        case .fish, .nature, .aquarium, .autumn, .koi, .snow: 0
        }
    }

    private static func initialPosition(for profile: Profile) -> Vector {
        switch profile {
        case .car, .motorcycle, .race: Vector(x: 0, y: -0.68)
        case .helicopter, .spaceship, .fish, .nature, .ufo, .aquarium, .autumn, .koi, .snow: .zero
        }
    }
}

private struct SeededGenerator: Equatable, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0xA5A5_A5A5_A5A5_A5A5 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    mutating func nextUnit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    mutating func nextIndex(upperBound: Int) -> Int {
        Int(next() % UInt64(upperBound))
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
