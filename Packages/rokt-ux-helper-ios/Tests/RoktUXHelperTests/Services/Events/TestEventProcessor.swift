import Foundation
import Combine
import XCTest
@testable import RoktUXHelper

@available(iOS 13.0, *)
final class TestEventProcessor: XCTestCase {
    
    func testEvents() {
        let expectation = expectation(description: "test event types")
        let allEventTypes = RoktUXEventType.allCases
        let date = Date()
        
        let sut = EventProcessor(queue: .userInitiated, integrationType: .sdk) { [weak self] payload in
            guard let self,
            let processedPayload: RoktUXEventsPayload = deserialize(payload) else {
                XCTFail("fail unwrapping")
                return
            }
            
            XCTAssertEqual(processedPayload.integration.name, "UX Helper iOS")
            XCTAssertEqual(processedPayload.integration.framework, "Swift")
            XCTAssertEqual(processedPayload.integration.platform, "iOS")
            
            let processedRequests = processedPayload.events
            XCTAssertEqual(processedRequests.count, 16)

            allEventTypes.forEach { eventType in
                
                guard let request = try? XCTUnwrap(processedRequests.first(where: { $0.eventType == eventType })) else {
                    XCTFail("fail with unwrapping EventRequest")
                    return
                }
                XCTAssertEqual(request.eventData, [.init(name: "key", value: "value \(request.eventType.rawValue)")])
                let metaData = [
                    RoktEventNameValue(name: BE_CLIENT_TIME_STAMP,
                                       value: EventDateFormatter.getDateString(date)),
                    RoktEventNameValue(name: BE_CAPTURE_METHOD,
                                       value: kClientProvided),
                    RoktEventNameValue(name: "name",
                                       value: "meta \(request.eventType.rawValue)")
                ]
                XCTAssertEqual(request.metadata, metaData)
            }
            expectation.fulfill()
        }
        
        allEventTypes.forEach {
            sut.handle(
                event: mockEvent(
                    eventType: $0,
                    date: date,
                    extraMetadata: [.init(name: "name", value: "meta \($0.rawValue)")],
                    eventData: ["key": "value \($0.rawValue)"]
                )
            )
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testS2SEvents() {
        let expectation = expectation(description: "test s2s event types")
        let allEventTypes = RoktUXEventType.allCases
        let date = Date()
        
        let sut = EventProcessor(queue: .userInitiated, integrationType: .s2s) { [weak self] payload in
            guard let self,
                  let processedPayload: RoktUXEventsPayload = deserialize(payload) else {
                XCTFail("fail unwrapping")
                return
            }
            
            XCTAssertEqual(processedPayload.integration.name, "UX Helper iOS")
            XCTAssertEqual(processedPayload.integration.framework, "Swift")
            XCTAssertEqual(processedPayload.integration.platform, "iOS")
            
            let processedRequests = processedPayload.events
            XCTAssertEqual(processedRequests.count, 14)
            expectation.fulfill()
        }
        allEventTypes.forEach {
            sut.handle(
                event: mockEvent(
                    eventType: $0,
                    date: date,
                    extraMetadata: [.init(name: "name", value: "meta \($0.rawValue)")],
                    eventData: ["key": "value \($0.rawValue)"]
                )
            )
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testEventDelayProcessing() {
        var expectation = expectation(description: "wait")
        var receivedPayload: [RoktEventRequest]?
        let sut = EventProcessor(delay: 0.5, queue: .userInitiated) { [weak self] payload in
            guard let self else {
                XCTFail("Fail self")
                return
            }
            receivedPayload = deserialize(payload)?.events
            expectation.fulfill()
        }
        
        sut.handle(event: mockEvent(eventType: .SignalActivation, date: Date()))
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(receivedPayload?.count, 1)
        XCTAssertEqual(receivedPayload?.first?.eventType, .SignalActivation)
        
        expectation = XCTestExpectation(description: "wait again")
        sut.handle(event: mockEvent(eventType: .SignalViewed, date: Date()))
        microSleep(0.1)
        sut.handle(event: mockEvent(eventType: .SignalImpression, date: Date()))
        microSleep(0.1)
        sut.handle(event: mockEvent(eventType: .SignalResponse, date: Date()))
        wait(for: [expectation], timeout: 2)
        XCTAssertEqual(receivedPayload?.count, 3)
        XCTAssertEqual(receivedPayload?[0].eventType, .SignalViewed)
        XCTAssertEqual(receivedPayload?[1].eventType, .SignalImpression)
        XCTAssertEqual(receivedPayload?[2].eventType, .SignalResponse)
    }

    func testEventRemoveDuplicates() {
        let expectation = expectation(description: "test duplicates")
        var receivedPayload: [RoktEventRequest]?
        let sut = EventProcessor(queue: .userInitiated) { [weak self] payload in
            guard let self else {
                XCTFail("Fail self")
                return
            }
            receivedPayload = deserialize(payload)?.events
            expectation.fulfill()
        }
        let date = Date()
        
        // Test case 1: Exact duplicate events (all properties identical)
        // Should be deduplicated
        let event1 = mockEvent(
            eventType: .SignalViewed,
            date: date,
            sessionId: "session1",
            parentGuid: "parent1",
            pageInstanceGuid: "page1"
        )
        sut.handle(event: event1)
        sut.handle(event: event1) // Exact duplicate
        
        // Test case 2: Same event but different sessionId
        // Should NOT be deduplicated
        sut.handle(event: mockEvent(
            eventType: .SignalViewed,
            date: date,
            sessionId: "session2", // Different sessionId
            parentGuid: "parent1",
            pageInstanceGuid: "page1"
        ))
        
        // Test case 3: Same event but different parentGuid
        // Should NOT be deduplicated
        sut.handle(event: mockEvent(
            eventType: .SignalViewed,
            date: date,
            sessionId: "session1",
            parentGuid: "parent2", // Different parentGuid
            pageInstanceGuid: "page1"
        ))
        
        // Test case 4: Same event but different pageInstanceGuid
        // Should NOT be deduplicated
        sut.handle(event: mockEvent(
            eventType: .SignalViewed,
            date: date,
            sessionId: "session1",
            parentGuid: "parent1",
            pageInstanceGuid: "page2" // Different pageInstanceGuid
        ))
        
        // Test case 5: Different event type
        // Should NOT be deduplicated
        sut.handle(event: mockEvent(
            eventType: .SignalImpression, // Different event type
            date: date,
            sessionId: "session1",
            parentGuid: "parent1",
            pageInstanceGuid: "page1"
        ))
        
        // Test case 6: Same event but different data
        // Should NOT be deduplicated
        sut.handle(event: mockEvent(
            eventType: .SignalViewed,
            date: date,
            sessionId: "session1",
            parentGuid: "parent1",
            pageInstanceGuid: "page1",
            eventData: ["key": "value1"] // Has event data
        ))
        sut.handle(event: mockEvent(
            eventType: .SignalViewed,
            date: date,
            sessionId: "session1",
            parentGuid: "parent1",
            pageInstanceGuid: "page1",
            eventData: ["key": "value2"] // Different event data
        ))
        
        // Test case 7: Same event, same data
        // Should be deduplicated
        let event7 = mockEvent(
            eventType: .SignalActivation,
            date: date,
            sessionId: "session1",
            parentGuid: "parent1",
            pageInstanceGuid: "page1",
            eventData: ["key": "value"]
        )
        sut.handle(event: event7)
        sut.handle(event: event7) // Duplicate
        
        // Test case 8: Same event but different metadata (extraMetadata)
        // Metadata should NOT affect deduplication
        sut.handle(event: mockEvent(
            eventType: .SignalResponse,
            date: date,
            sessionId: "session1",
            parentGuid: "parent1",
            pageInstanceGuid: "page1",
            extraMetadata: [.init(name: "meta1", value: "value1")]
        ))
        sut.handle(event: mockEvent(
            eventType: .SignalResponse,
            date: date,
            sessionId: "session1",
            parentGuid: "parent1",
            pageInstanceGuid: "page1",
            extraMetadata: [.init(name: "meta2", value: "value2")] // Different metadata
        ))
        
        wait(for: [expectation], timeout: 1)
        
        // Verify the correct deduplication
        XCTAssertNotNil(receivedPayload, "Payload should not be nil")
        
        // Count total events after deduplication
        // We sent 11 events, but only 9 should remain after deduplication
        XCTAssertEqual(receivedPayload?.count, 9, "Should have 9 unique events after deduplication")
        
        // Count events by type for verification
        let viewedEvents = receivedPayload?.filter { $0.eventType == .SignalViewed }
        XCTAssertEqual(viewedEvents?.count, 6, "Should have 6 SignalViewed events")
        
        let impressionEvents = receivedPayload?.filter { $0.eventType == .SignalImpression }
        XCTAssertEqual(impressionEvents?.count, 1, "Should have 1 SignalImpression event")
        
        let activationEvents = receivedPayload?.filter { $0.eventType == .SignalActivation }
        XCTAssertEqual(activationEvents?.count, 1, "Should have 1 SignalActivation event after deduplication")
        
        let responseEvents = receivedPayload?.filter { $0.eventType == .SignalResponse }
        // Note: If metadata doesn't affect deduplication, this should be 1
        // If metadata does affect deduplication, this should be 2
        // The current implementation suggests metadata should not affect deduplication
        // but we're seeing in the tests it does - so we need to validate this behavior
        XCTAssertEqual(responseEvents?.count, 1, "Should have 1 SignalResponse event")
    }
    
    func testEventDeduplicationDetails() {
        // This test focuses on validating the exact behavior of the ProcessedEvent equality
        // to ensure our understanding matches the implementation
        
        let expectation = expectation(description: "test detailed deduplication")
        var receivedPayload: [RoktEventRequest]?
        let sut = EventProcessor(queue: .userInitiated) { [weak self] payload in
            guard let self else {
                XCTFail("Fail self")
                return
            }
            receivedPayload = deserialize(payload)?.events
            expectation.fulfill()
        }
        
        // Create an event
        let baseEvent = mockEvent(
            eventType: .SignalViewed,
            date: Date(),
            sessionId: "session1",
            parentGuid: "parent1",
            pageInstanceGuid: "page1",
            eventData: ["key": "value"]
        )
        
        // Send the base event
        sut.handle(event: baseEvent)
        
        // Test that changing metadata does NOT affect deduplication
        // This is to verify our understanding of the implementation
        sut.handle(event: mockEventWithModification(
            baseEvent: baseEvent,
            modifyMetadata: [.init(name: "differentMeta", value: "value")]
        ))
        
        // Test that changing the time does NOT affect deduplication
        sut.handle(event: mockEventWithModification(
            baseEvent: baseEvent,
            modifyDate: Date(timeIntervalSinceNow: 100)
        ))
        
        // Test that changing the JWT token does NOT affect deduplication
        sut.handle(event: mockEventWithModification(
            baseEvent: baseEvent,
            modifyJwtToken: "differentToken"
        ))
        
        wait(for: [expectation], timeout: 1)
        
        // Since the ProcessedEvent equality is based on sessionId, parentGuid, eventType, pageInstanceGuid, and eventData,
        // changing metadata, date or JWT token should not create new events
        XCTAssertEqual(receivedPayload?.count, 1, "All events should be considered duplicates except for the first one")
    }

    func testSignalUserInteractionBypassesDeduplication() {
        let expectation = expectation(description: "user interaction should not deduplicate")
        var receivedPayload: [RoktEventRequest]?
        let date = Date()

        let sut = EventProcessor(queue: .userInitiated) { [weak self] payload in
            guard let self else {
                XCTFail("Fail self")
                return
            }
            receivedPayload = deserialize(payload)?.events
            expectation.fulfill()
        }

        let event = mockEvent(
            eventType: .SignalUserInteraction,
            date: date,
            eventData: ["action": "click"]
        )

        sut.handle(event: event)
        sut.handle(event: event)

        wait(for: [expectation], timeout: 1)

        XCTAssertEqual(receivedPayload?.count, 2)
        XCTAssertEqual(receivedPayload?.filter { $0.eventType == .SignalUserInteraction }.count, 2)
    }

    func testDelayProcessorDeallocation() {
        let expectation = expectation(description: "wait")
        var receivedPayload: [RoktEventRequest]?
        weak var weakSut: EventProcessor?
        var sut: EventProcessor? = EventProcessor(delay: 1, queue: .userInitiated) { [weak self] payload in
            guard let self else {
                XCTFail("Fail self")
                return
            }
            XCTAssertNotNil(weakSut)
            receivedPayload = deserialize(payload)?.events
            expectation.fulfill()
        }
        weakSut = sut
        sut?.handle(event: mockEvent(eventType: .SignalActivation, date: Date()))
        sut = nil

        wait(for: [expectation], timeout: 3)

        XCTAssertNil(weakSut)
        XCTAssertEqual(receivedPayload?.count, 1)
        XCTAssertEqual(receivedPayload?.first?.eventType, .SignalActivation)
    }

    private func microSleep(_ seconds: Double) {
        usleep(useconds_t(Int32(seconds * 1000000)))
    }
    
    private func deserialize(_ events: [String: Any]) -> RoktUXEventsPayload? {
        let data = try? JSONSerialization.data(withJSONObject: events, options: [])
        return data.flatMap { try? JSONDecoder().decode(RoktUXEventsPayload.self, from: $0) }
    }
    
    private func mockEvent(
        eventType: RoktUXEventType,
        date: Date,
        sessionId: String = "sessionId",
        parentGuid: String = "parentGuid",
        pageInstanceGuid: String = "pageInstanceGuid",
        extraMetadata: [RoktEventNameValue] = [],
        eventData: [String: String] = [:]
    ) -> RoktEventRequest {
        .init(
            sessionId: sessionId,
            eventType: eventType,
            parentGuid: parentGuid,
            eventTime: date,
            extraMetadata: extraMetadata,
            eventData: eventData,
            pageInstanceGuid: pageInstanceGuid,
            jwtToken: "token"
        )
    }
    
    private func mockEventWithModification(
        baseEvent: RoktEventRequest,
        modifyDate: Date? = nil,
        modifyMetadata: [RoktEventNameValue]? = nil, 
        modifyJwtToken: String? = nil
    ) -> RoktEventRequest {
        .init(
            sessionId: baseEvent.sessionId,
            eventType: baseEvent.eventType,
            parentGuid: baseEvent.parentGuid,
            eventTime: modifyDate ?? EventDateFormatter.dateFormatter.date(from: baseEvent.eventTime)!,
            extraMetadata: modifyMetadata ?? baseEvent.metadata,
            eventData: baseEvent.eventData.reduce(into: [String: String]()) { $0[$1.name] = $1.value },
            pageInstanceGuid: baseEvent.pageInstanceGuid,
            jwtToken: modifyJwtToken ?? baseEvent.jwtToken
        )
    }
}
