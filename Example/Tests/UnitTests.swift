import XCTest
import Nimble
@testable import Rokt_Widget

class UnitTests: XCTestCase {

    override func setUp() {
        super.setUp()
        stubInit()
        Rokt.initWith(roktTagId: "123123123")
    }

    func testInit() {
        expect(Rokt.shared).to(beAKindOf(Rokt.self))
    }

    func testExpectEventuallyRecordedFailsOnDuplicateInSecondAsyncPost() {
        var events: [EventModel] = []
        stubDiagnostics()
        stubEvents { event in
            events.append(event)
        }
        defer {
            Rokt.shared.roktImplementation.makeTxnEventServiceOverride = nil
            EventDeliveryFence.shared.reset()
        }

        let expected = EventModel(
            eventType: "SignalImpression",
            parentGuid: "31b61e93-24bd-4735-995a-2f14d0673ec3",
            pageInstanceGuid: "bfbc0187-2d0f-4ad4-be6b-7545f9273567"
        )
        let txnEvent = TxnEvent(
            eventType: "impression",
            instanceId: "instance-1",
            timestamp: 1_700_000_000_000,
            data: [
                "parent_id": .string(expected.parentGuid),
                "page_instance_guid": .string(expected.pageInstanceGuid ?? "")
            ]
        )

        Rokt.shared.roktImplementation.dispatchTxnEvents([txnEvent])
        expect(events.count).toEventually(equal(1), timeout: .seconds(5))
        expect(EventDeliveryFence.shared.isIdle).toEventually(beTrue(), timeout: .seconds(5))

        stubEvents(delay: .milliseconds(300)) { event in
            events.append(event)
        }
        Rokt.shared.roktImplementation.dispatchTxnEvents([txnEvent])

        XCTExpectFailure("Duplicate delivered in a second async POST fails expectEventuallyRecorded") {
            expectEventuallyRecorded([expected], in: events, timeout: .seconds(5))
        }
        expect(events.count).to(equal(2))
    }

}
