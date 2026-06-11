import XCTest
@testable import Rokt_Widget
@testable internal import RoktUXHelper

/// The SDK-only `loadLayout(pageModel:)` overload no longer takes `onLoad`/`onUnload`
/// view-lifecycle closures. The loaded-placement count that drives `clearCallBacks`
/// (state-bag teardown) is now derived from the RoktUXEvent lifecycle stream in
/// `callOnRoktUXEvent`. These tests pin that wiring:
///   - load   ← `LayoutInteractive`            (increments once per placement)
///   - unload ← `LayoutClosed` / `LayoutCompleted` (decrements once per placement)
/// so the count stays balanced and the state bag is removed exactly when the last
/// placement goes (the `StateBagManager` removes the bag when the count hits 0).
final class TestRoktUXEventPlacementCount: XCTestCase {

    private let executeId = "test-execute-id"

    /// Seeds a fresh implementation with a state bag whose `loadedPlacements` is 0
    /// (the default for a newly-created `ExecuteStateBag`).
    private func makeImplementation() -> (RoktInternalImplementation, ExecuteStateBag) {
        let impl = RoktInternalImplementation()
        let bag = ExecuteStateBag(uxHelper: nil, onRoktEvent: nil)
        impl.stateManager.addState(id: executeId, state: bag)
        return (impl, bag)
    }

    func test_layoutInteractive_increasesLoadedPlacements() {
        let (impl, bag) = makeImplementation()

        impl.callOnRoktUXEvent(executeId, uxEvent: RoktUXEvent.LayoutInteractive(layoutId: "l1"))

        XCTAssertEqual(bag.loadedPlacements, 1)
    }

    func test_layoutClosed_afterInteractive_decrementsAndTearsDown() {
        let (impl, _) = makeImplementation()

        impl.callOnRoktUXEvent(executeId, uxEvent: RoktUXEvent.LayoutInteractive(layoutId: "l1"))
        impl.callOnRoktUXEvent(executeId, uxEvent: RoktUXEvent.LayoutClosed(layoutId: "l1"))

        // Count returned to 0 → the state bag is removed (clearCallBacks fired).
        XCTAssertNil(impl.stateManager.getState(id: executeId))
    }

    func test_layoutCompleted_afterInteractive_decrementsAndTearsDown() {
        let (impl, _) = makeImplementation()

        impl.callOnRoktUXEvent(executeId, uxEvent: RoktUXEvent.LayoutInteractive(layoutId: "l1"))
        impl.callOnRoktUXEvent(executeId, uxEvent: RoktUXEvent.LayoutCompleted(layoutId: "l1"))

        XCTAssertNil(impl.stateManager.getState(id: executeId))
    }

    /// Two placements under one execute: the count must reach 0 only after BOTH close.
    func test_multiPlacement_countStaysBalanced() {
        let (impl, bag) = makeImplementation()

        impl.callOnRoktUXEvent(executeId, uxEvent: RoktUXEvent.LayoutInteractive(layoutId: "l1"))
        impl.callOnRoktUXEvent(executeId, uxEvent: RoktUXEvent.LayoutInteractive(layoutId: "l2"))
        XCTAssertEqual(bag.loadedPlacements, 2)

        impl.callOnRoktUXEvent(executeId, uxEvent: RoktUXEvent.LayoutClosed(layoutId: "l1"))
        XCTAssertEqual(impl.stateManager.getState(id: executeId)?.loadedPlacements, 1)

        impl.callOnRoktUXEvent(executeId, uxEvent: RoktUXEvent.LayoutCompleted(layoutId: "l2"))
        XCTAssertNil(impl.stateManager.getState(id: executeId))
    }

    /// LayoutReady is forwarded to the partner but must NOT count as a load — otherwise
    /// the count would double (Ready + Interactive both fire per placement) and never reach 0.
    func test_layoutReady_doesNotAffectPlacementCount() {
        let (impl, bag) = makeImplementation()

        impl.callOnRoktUXEvent(executeId, uxEvent: RoktUXEvent.LayoutReady(layoutId: "l1"))

        XCTAssertEqual(bag.loadedPlacements, 0)
        XCTAssertNotNil(impl.stateManager.getState(id: executeId))
    }
}
