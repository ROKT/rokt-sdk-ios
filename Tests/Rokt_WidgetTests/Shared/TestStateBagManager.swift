import XCTest
@testable import Rokt_Widget

class TestStateBagManager: XCTestCase {

    var sut: StateBagManager!

    override func setUp() {
        sut = StateBagManager()
    }

    func testGivenMultipleStateBags_ThenReturnCorrectState() {
        let bags = [
            MockBag(),
            MockBag(),
            MockBag()
        ]
        bags.forEach {
            sut.addState(id: $0.id, state: $0)
        }
        XCTAssertEqual(sut.stateMap.count, 3)
        XCTAssertEqual((sut.getState(id: bags[0].id) as? MockBag)?.id, bags[0].id)
        XCTAssertEqual((sut.getState(id: bags[1].id) as? MockBag)?.id, bags[1].id)
        XCTAssertEqual((sut.getState(id: bags[2].id) as? MockBag)?.id, bags[2].id)

        sut.removeState(id: bags[2].id)
        XCTAssertEqual(sut.stateMap.count, 2)
        XCTAssertNil(sut.find(where: { ($0 as? MockBag)?.id == bags[2].id }))
    }

    func testGivenNoReference_ThenRemoveStateBag() {
        var bag: MockBag? = MockBag()
        bag?.uxHelper = MockUXHelper()
        weak var uxHelper: AnyObject? = bag?.uxHelper
        sut.addState(id: "1", state: bag!)
        bag = nil

        sut.increasePlacements(id: "1")
        XCTAssertEqual(sut.getState(id: "1")?.loadedPlacements, 1)
        sut.increasePlacements(id: "1")
        XCTAssertEqual(sut.getState(id: "1")?.loadedPlacements, 2)
        XCTAssertNotNil(uxHelper)

        sut.decreasePlacements(id: "1")
        XCTAssertEqual(sut.getState(id: "1")?.loadedPlacements, 1)
        sut.decreasePlacements(id: "1")
        XCTAssertNil(sut.getState(id: "1"))
        XCTAssertNil(uxHelper)
    }

    func testGivenInstantPurchaseIntiated_ThenRetainState() {
        var bag: MockBag? = MockBag()
        bag?.uxHelper = MockUXHelper()
        weak var uxHelper: AnyObject? = bag?.uxHelper
        sut.addState(id: "1", state: bag!)
        bag = nil

        sut.initiateInstantPurchase(id: "1")
        sut.increasePlacements(id: "1")
        sut.decreasePlacements(id: "1")
        XCTAssertTrue(sut.getState(id: "1")!.instantPurchaseInitiated)

        sut.finishInstantPurchase(id: "1")
        XCTAssertNil(sut.getState(id: "1"))
        XCTAssertNil(uxHelper)
    }

    func testGivenAnOutstandingPurchase_ThenKeepStateUntilNothingHoldsIt() {
        var bag: MockBag? = MockBag()
        bag?.uxHelper = MockUXHelper()
        weak var uxHelper: AnyObject? = bag?.uxHelper
        sut.addState(id: "1", state: bag!)
        bag = nil
        var purchaseOutstanding = true
        sut.hasOutstandingPurchase = { id in id == "1" && purchaseOutstanding }

        // Two purchases started; the first finished and cleared the flag while the second is still out.
        sut.increasePlacements(id: "1")
        sut.initiateInstantPurchase(id: "1")
        sut.initiateInstantPurchase(id: "1")
        sut.finishInstantPurchase(id: "1")
        sut.decreasePlacements(id: "1")
        XCTAssertNotNil(sut.getState(id: "1"), "The outstanding purchase keeps the state after the last placement unloads")
        XCTAssertNotNil(uxHelper)

        sut.removeStateIfUnused(id: "1")
        XCTAssertNotNil(sut.getState(id: "1"), "Checking again changes nothing while the purchase is outstanding")

        purchaseOutstanding = false
        sut.removeStateIfUnused(id: "unknown")
        XCTAssertEqual(sut.stateMap.count, 1, "An id with no state is left alone")

        sut.removeStateIfUnused(id: "1")
        XCTAssertNil(sut.getState(id: "1"))
        XCTAssertNil(uxHelper)
    }

    func testGivenADroppedPurchase_ThenClearTheFlagAndRemoveTheStateWithoutAFinish() {
        var bag: MockBag? = MockBag()
        bag?.uxHelper = MockUXHelper()
        weak var uxHelper: AnyObject? = bag?.uxHelper
        sut.addState(id: "1", state: bag!)
        bag = nil
        var purchaseOutstanding = true
        sut.hasOutstandingPurchase = { id in id == "1" && purchaseOutstanding }

        // The tap set the flag, and the checkout it started is still outstanding when the last placement unloads.
        sut.increasePlacements(id: "1")
        sut.initiateInstantPurchase(id: "1")
        sut.decreasePlacements(id: "1")
        XCTAssertNotNil(sut.getState(id: "1"))

        // The checkout is dropped rather than finished, so nothing will ever call `finishInstantPurchase` for it.
        purchaseOutstanding = false
        sut.removeStateIfUnused(id: "1")
        XCTAssertNil(sut.getState(id: "1"), "A dropped purchase releases the state without a finish of its own")
        XCTAssertNil(uxHelper)
    }

    func testGivenADroppedPurchaseWhileAPlacementIsLoaded_ThenClearTheFlagAndKeepTheStateUntilItUnloads() {
        var bag: MockBag? = MockBag()
        bag?.uxHelper = MockUXHelper()
        weak var uxHelper: AnyObject? = bag?.uxHelper
        sut.addState(id: "1", state: bag!)
        bag = nil

        sut.increasePlacements(id: "1")
        sut.initiateInstantPurchase(id: "1")
        sut.removeStateIfUnused(id: "1")
        XCTAssertNotNil(sut.getState(id: "1"), "A loaded placement keeps the state")
        XCTAssertEqual(sut.getState(id: "1")?.instantPurchaseInitiated, false, "The dropped purchase no longer holds it")

        sut.decreasePlacements(id: "1")
        XCTAssertNil(sut.getState(id: "1"), "The state goes with its last placement")
        XCTAssertNil(uxHelper)
    }

    func testGivenAPurchaseStillOutstanding_ThenRemoveStateIfUnusedLeavesTheFlagAlone() {
        let bag = MockBag()
        sut.addState(id: "1", state: bag)
        sut.hasOutstandingPurchase = { $0 == "1" }
        sut.initiateInstantPurchase(id: "1")

        sut.removeStateIfUnused(id: "1")

        XCTAssertTrue(bag.instantPurchaseInitiated, "A purchase still outstanding may yet finish and clear the flag itself")
        XCTAssertNotNil(sut.getState(id: "1"))
    }
}

private class MockUXHelper {
    var id: String = UUID().uuidString
}

private class MockBag: Bag {
    var loadedPlacements: Int = 0
    var instantPurchaseInitiated: Bool = false
    var id: String = UUID().uuidString
    var uxHelper: AnyObject?
    var onLoad: (() -> Void)?
    var onUnLoad: (() -> Void)?
    var onEmbeddedSizeChange: ((String, CGFloat) -> Void)?
    var onRoktEvent: ((RoktEvent) -> Void)?
}
