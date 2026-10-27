import Combine
import XCTest
@testable import PushDebug

final class DebugStateTests: XCTestCase {
    func testClockDoesNotPublishAnimationOrUpdateHiddenVisualizer() {
        let state = DebugState()
        var notifications = 0
        let subscription = state.objectWillChange.sink { notifications += 1 }
        let initialBars = state.barHeights

        state.advanceAnimationFrame()

        XCTAssertEqual(notifications, 0)
        XCTAssertEqual(state.animationPhase, 0)
        XCTAssertEqual(state.barHeights, initialBars)
        withExtendedLifetime(subscription) {}
    }

    func testEachAnimatedDemoPublishesOneFrameWithoutUpdatingHiddenVisualizer() {
        for demo in [DemoType.visualizer, .gradient, .pong, .starfield] {
            let state = DebugState()
            state.currentDemo = demo
            state.stars = [.init(x: 500, y: 90, z: 0.8)]
            let initialBars = state.barHeights
            var notifications = 0
            let subscription = state.objectWillChange.sink { notifications += 1 }

            state.advanceAnimationFrame()

            XCTAssertEqual(notifications, 1, "\(demo) should publish one frame")
            if demo != .visualizer {
                XCTAssertEqual(state.barHeights, initialBars, "\(demo) should not animate hidden bars")
            }
            withExtendedLifetime(subscription) {}
        }
    }

    func testAnimationFramesDoNotInvalidateDemoSelection() {
        let state = DebugState()
        state.currentDemo = .pong
        var selectionNotifications = 0
        let subscription = state.selection.objectWillChange.sink { selectionNotifications += 1 }

        for _ in 0..<60 { state.advanceAnimationFrame() }
        XCTAssertEqual(selectionNotifications, 0)

        state.currentDemo = .gradient
        XCTAssertEqual(selectionNotifications, 1)
        XCTAssertEqual(state.selection.currentDemo, .gradient)
        state.advanceAnimationFrame()
        XCTAssertEqual(selectionNotifications, 1)
        withExtendedLifetime(subscription) {}
    }

    func testClockTickOnlyInvalidatesVisibleClock() {
        let state = DebugState()
        var notifications = 0
        let subscription = state.objectWillChange.sink { notifications += 1 }
        let date = Date(timeIntervalSince1970: 1234)

        state.updateTime(date)
        XCTAssertEqual(state.time, date)
        XCTAssertEqual(notifications, 1)

        state.currentDemo = .pong
        state.updateTime(date.addingTimeInterval(1))
        XCTAssertEqual(state.time, date.addingTimeInterval(1))
        XCTAssertEqual(notifications, 1)
        withExtendedLifetime(subscription) {}
    }

    func testPongStillAdvancesBallAndPlayerInOneFrame() {
        let state = DebugState()
        state.currentDemo = .pong
        state.playerInput = 1

        state.advanceAnimationFrame()

        XCTAssertEqual(state.ballX, 486)
        XCTAssertEqual(state.ballY, 84)
        XCTAssertEqual(state.paddle1Y, 65)
        XCTAssertEqual(state.paddle2Y, 63.5)
        XCTAssertEqual(state.animationPhase, 0)
    }

    func testPongScoringAndResetPublishOnlyOneFrame() {
        let state = DebugState()
        state.currentDemo = .pong
        state.ballX = 960
        var notifications = 0
        let subscription = state.objectWillChange.sink { notifications += 1 }

        state.advanceAnimationFrame()

        XCTAssertEqual(notifications, 1)
        XCTAssertEqual(state.score1, 1)
        XCTAssertEqual(state.ballX, 480)
        XCTAssertEqual(state.ballY, 80)
        XCTAssertEqual(state.ballVX, -5)
        withExtendedLifetime(subscription) {}
    }

    func testMouseInputClampsPaddleAndSkipsDuplicateOrInactiveUpdates() {
        let state = DebugState()
        state.currentDemo = .pong
        var notifications = 0
        let subscription = state.objectWillChange.sink { notifications += 1 }

        state.setPaddlePosition(-100)
        XCTAssertEqual(state.paddle1Y, 20)
        XCTAssertEqual(notifications, 1)
        state.setPaddlePosition(-50)
        XCTAssertEqual(notifications, 1)
        state.setPaddlePosition(1000)
        XCTAssertEqual(state.paddle1Y, 140)
        XCTAssertEqual(notifications, 2)

        state.currentDemo = .clock
        state.setPaddlePosition(70)
        XCTAssertEqual(state.paddle1Y, 140)
        XCTAssertEqual(notifications, 2)
        withExtendedLifetime(subscription) {}
    }

    func testStarfieldPublishesOneCompletedFrameInsteadOfEachCoordinate() {
        let state = DebugState()
        state.stars = Array(repeating: .init(x: 500, y: 90, z: 0.8), count: 150)
        var notifications = 0
        let subscription = state.objectWillChange.sink { notifications += 1 }

        state.updateStarfield()

        XCTAssertEqual(notifications, 1)
        XCTAssertEqual(state.stars[0].x, 500.96, accuracy: 0.0001)
        XCTAssertEqual(state.stars[0].y, 90.48, accuracy: 0.0001)
        XCTAssertEqual(state.stars[0].z, 0.792, accuracy: 0.0001)
        withExtendedLifetime(subscription) {}
    }
}
