import XCTest
@testable import Rokt_Widget
internal import RoktUXHelper

class TestEventQueue: XCTestCase {

    func test_send_one_event() {
        let expectation = self.expectation(description: "event to be called")
        EventQueue.call(event: EventRequest(sessionId: "session",
                                            eventType: .SignalLoadStart,
                                            parentGuid: "2",
                                            jwtToken: "jwt")) { events in
            XCTAssertEqual(events.count, 1)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 0.3, handler: nil)
    }

    func test_send_two_events_separatly() {
        let expectation1 = self.expectation(description: "first event to be called")
        EventQueue.call(event: getSampleEvent()) { events in
            XCTAssertEqual(events.count, 1)
            expectation1.fulfill()
        }
        waitForExpectations(timeout: 0.3, handler: nil)

        let expectation2 = self.expectation(description: "second event to be called")
        EventQueue.call(event: getSampleEvent()) { events in
            XCTAssertEqual(events.count, 1)
            expectation2.fulfill()
        }
        waitForExpectations(timeout: 0.3, handler: nil)
    }

    func test_send_multipe_events_together() {
        let expectation = self.expectation(description: "events to be called")
        EventQueue.call(event: getSampleEvent()) { _ in
        }
        EventQueue.call(event: getSampleEvent()) { _ in
        }
        EventQueue.call(event: getSampleEvent()) { _ in
        }
        EventQueue.call(event: getSampleEvent()) { events in
            XCTAssertEqual(events.count, 4)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 0.3, handler: nil)
    }

    func test_send_multipe_events_with_two_calls() {
        let expectation = self.expectation(description: "first events to be called")
        EventQueue.call(event: getSampleEvent()) { _ in
        }
        EventQueue.call(event: getSampleEvent()) { events in
            XCTAssertEqual(events.count, 2)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 0.3, handler: nil)

        let expectation2 = self.expectation(description: "second events to be called")
        EventQueue.call(event: getSampleEvent()) { _ in
        }
        EventQueue.call(event: getSampleEvent()) { _ in
        }
        EventQueue.call(event: getSampleEvent()) { events in
            XCTAssertEqual(events.count, 3)
            expectation2.fulfill()
        }
        waitForExpectations(timeout: 0.3, handler: nil)
    }

    func test_flush_drainsBufferedEventsImmediately() {
        // flush() must deliver synchronously, well before the 0.25s debounce timer would fire.
        let expectation = self.expectation(description: "flush drains buffered events")
        EventQueue.call(event: getSampleEvent()) { events in
            XCTAssertEqual(events.count, 1)
            expectation.fulfill()
        }

        EventQueue.flush()

        waitForExpectations(timeout: 0.1, handler: nil)
    }

    func test_flush_whenBufferEmpty_isNoOp() {
        var callbackCount = 0
        EventQueue.call(event: getSampleEvent()) { _ in callbackCount += 1 }

        EventQueue.flush() // drains the single buffered event
        EventQueue.flush() // buffer now empty -> must not invoke the callback again

        XCTAssertEqual(callbackCount, 1)
    }

    private func getSampleEvent() -> EventRequest {
        return EventRequest(sessionId: "", eventType: .SignalLoadStart, parentGuid: "", jwtToken: "jwt")
    }

}
