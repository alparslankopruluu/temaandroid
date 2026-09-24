import XCTest
@testable import ScreenMotion

final class InteractiveSceneBehaviorTests: XCTestCase {
    func testEveryApprovedProfileStaysWithinNormalizedBounds() {
        for profile in InteractiveSceneBehavior.Profile.allCases {
            var behavior = InteractiveSceneBehavior(profile: profile, mode: .score, seed: 42)

            for frame in 0..<300 {
                let input = InteractiveSceneBehavior.Input(
                    tilt: .init(x: 4, y: -4),
                    drag: .init(x: frame.isMultiple(of: 2) ? -3 : 3, y: 2)
                )
                behavior.update(deltaTime: 1.0 / 60.0, time: Double(frame) / 60, input: input)
            }

            XCTAssertTrue((-1...1).contains(behavior.state.position.x), "Profile: \(profile)")
            XCTAssertTrue((-1...1).contains(behavior.state.position.y), "Profile: \(profile)")
            XCTAssertTrue((-1...1).contains(behavior.state.velocity.x), "Profile: \(profile)")
            XCTAssertTrue((-1...1).contains(behavior.state.velocity.y), "Profile: \(profile)")
        }
    }

    func testEqualSeedsAndFrameInputsProduceIdenticalResults() {
        var first = InteractiveSceneBehavior(profile: .spaceship, mode: .score, seed: 73)
        var second = InteractiveSceneBehavior(profile: .spaceship, mode: .score, seed: 73)

        for frame in 0..<180 {
            let input = InteractiveSceneBehavior.Input(
                tilt: .init(x: sin(Double(frame) * 0.13), y: cos(Double(frame) * 0.09)),
                tap: frame == 37 ? .init(x: 0.4, y: -0.2) : nil
            )
            let firstEvents = first.update(deltaTime: 1.0 / 60.0, time: Double(frame) / 60, input: input)
            let secondEvents = second.update(deltaTime: 1.0 / 60.0, time: Double(frame) / 60, input: input)
            XCTAssertEqual(firstEvents, secondEvents)
        }

        XCTAssertEqual(first, second)
    }

    func testDragTakesPriorityOverTiltAndInputsAreNormalized() {
        let input = InteractiveSceneBehavior.Input(
            tilt: .init(x: -4, y: 8),
            drag: .init(x: 7, y: -9)
        )
        var behavior = InteractiveSceneBehavior(profile: .car, seed: 1)

        behavior.update(deltaTime: 0.1, time: 0.1, input: input)

        XCTAssertEqual(input.tilt, .init(x: -1, y: 1))
        XCTAssertEqual(input.drag, .init(x: 1, y: -1))
        XCTAssertGreaterThan(behavior.state.velocity.x, 0)
    }

    func testTapCreatesTheProfileResponse() {
        for profile in InteractiveSceneBehavior.Profile.allCases {
            var behavior = InteractiveSceneBehavior(profile: profile, seed: 9)
            let beforeVelocity = behavior.state.velocity

            let events = behavior.update(
                deltaTime: 1.0 / 60.0,
                time: 1,
                input: .init(tap: .init(x: 0.8, y: 0.7))
            )

            XCTAssertTrue(events.contains(.tapResponded(profile: profile)), "Profile: \(profile)")
            XCTAssertEqual(behavior.state.tapResponse, 1, "Profile: \(profile)")
            if [.helicopter, .spaceship, .ufo, .fish, .aquarium, .koi].contains(profile) {
                XCTAssertNotEqual(behavior.state.velocity, beforeVelocity, "Profile: \(profile)")
            }
        }
    }

    func testCalmModeNeverScoresOrCollides() {
        for profile in InteractiveSceneBehavior.Profile.allCases {
            var behavior = InteractiveSceneBehavior(profile: profile, mode: .calm, seed: 21, highScore: 8)
            var allEvents: [InteractiveSceneBehavior.Event] = []

            for frame in 0..<900 {
                allEvents += behavior.update(deltaTime: 1.0 / 60.0, time: Double(frame) / 60)
            }

            XCTAssertEqual(behavior.state.score, 0, "Profile: \(profile)")
            XCTAssertEqual(behavior.state.highScore, 8, "Profile: \(profile)")
            XCTAssertFalse(allEvents.contains { event in
                if case .collision = event { return true }
                return false
            }, "Profile: \(profile)")
        }
    }

    func testFishAndNatureRemainNonScoringWhenScoreModeIsRequested() {
        for profile in [InteractiveSceneBehavior.Profile.fish, .nature, .aquarium, .autumn, .koi, .snow] {
            var behavior = InteractiveSceneBehavior(profile: profile, mode: .score, seed: 11)

            for frame in 0..<300 {
                behavior.update(deltaTime: 1.0 / 60.0, time: Double(frame) / 60)
            }

            XCTAssertFalse(behavior.isScoreActive)
            XCTAssertEqual(behavior.state.score, 0)
        }
    }

    func testCollisionPublishesCollisionHighScoreAndResetEventsInOrder() {
        var behavior = InteractiveSceneBehavior(profile: .car, mode: .score, seed: 5)
        var collisionEvents: [InteractiveSceneBehavior.Event] = []

        for frame in 0..<1_200 where collisionEvents.isEmpty {
            let nearest = behavior.obstacles.min { lhs, rhs in lhs.position.y < rhs.position.y }
            let targetX = nearest?.position.x ?? 0
            let events = behavior.update(
                deltaTime: 1.0 / 60.0,
                time: Double(frame) / 60,
                input: .init(drag: .init(x: targetX, y: 0))
            )
            if events.contains(where: { if case .collision = $0 { true } else { false } }) {
                collisionEvents = events
            }
        }

        let collisionIndex = collisionEvents.firstIndex { if case .collision = $0 { true } else { false } }
        let highScoreIndex = collisionEvents.firstIndex { if case .highScoreChanged = $0 { true } else { false } }
        let resetIndex = collisionEvents.firstIndex { if case .reset = $0 { true } else { false } }

        XCTAssertNotNil(collisionIndex)
        XCTAssertNotNil(highScoreIndex)
        XCTAssertNotNil(resetIndex)
        if let collisionIndex, let highScoreIndex, let resetIndex {
            XCTAssertLessThan(collisionIndex, highScoreIndex)
            XCTAssertLessThan(highScoreIndex, resetIndex)
        }
        XCTAssertEqual(behavior.state.run, 1)
        XCTAssertEqual(behavior.state.score, 0)
        XCTAssertGreaterThan(behavior.state.highScore, 0)
        XCTAssertEqual(behavior.state.position, .init(x: 0, y: -0.68))
    }
}
