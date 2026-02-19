import XCTest
@testable import Rokt_Widget
@testable internal import RoktUXHelper

class TestPlatformEventProcessor: XCTestCase {

    private var sut: PlatformEventProcessor!
    private var mockStateManager: MockStateManager!

    override func setUp() {
        super.setUp()
        mockStateManager = MockStateManager()
        sut = PlatformEventProcessor(stateBagManager: mockStateManager)
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Instant purchase Tests

    func testGivenInstantPurchaseInitiatedSignal_ThenUpdateState() {
        let payload = mockEventsPayload(
            events: [
                .mock(eventType: .SignalCartItemInstantPurchaseInitiated)
            ]
        )!
        sut.process(payload, executeId: "1", cacheProperties: nil)

        XCTAssertTrue(mockStateManager.initiateInstantPurchaseCalled)
        XCTAssertEqual(mockStateManager.stateIdRetrieved, "1")
    }

    func testGivenInstantPurchaseSuccessSignal_ThenUpdateState() {
        let payload = mockEventsPayload(
            events: [
                .mock(eventType: .SignalCartItemInstantPurchaseInitiated),
                .mock(eventType: .SignalCartItemInstantPurchase)
            ]
        )!
        sut.process(payload, executeId: "1", cacheProperties: nil)

        XCTAssertTrue(mockStateManager.initiateInstantPurchaseCalled)
        XCTAssertTrue(mockStateManager.finishInstantPurchaseCalled)
        XCTAssertEqual(mockStateManager.stateIdRetrieved, "1")
    }

    func testGivenInstantPurchaseFailSignal_ThenUpdateState() {
        let payload = mockEventsPayload(
            events: [
                .mock(eventType: .SignalCartItemInstantPurchaseInitiated),
                .mock(eventType: .SignalCartItemInstantPurchaseFailure)
            ]
        )!
        sut.process(payload, executeId: "1", cacheProperties: nil)

        XCTAssertTrue(mockStateManager.initiateInstantPurchaseCalled)
        XCTAssertTrue(mockStateManager.finishInstantPurchaseCalled)
        XCTAssertEqual(mockStateManager.stateIdRetrieved, "1")
    }

    func test_insert_ProcessedEvent() {
        let eventRequest = EventRequest(
            sessionId: "session1",
            eventType: .SignalImpression,
            parentGuid: "parent1",
            attributes: ["key": "value"],
            pageInstanceGuid: "page1",
            jwtToken: "jwt1"
        )
        let result = sut.insertProcessedEvent(eventRequest)
        XCTAssertTrue(result)
        XCTAssertEqual(sut.processedEvents.count, 1)
    }

    func test_GetEventParams_valid() {
        let eventRequest = RoktEventRequest(
            sessionId: "session1",
            eventType: .SignalImpression,
            parentGuid: "parent1",
            eventData: ["dataKey": "dataValue"],
            pageInstanceGuid: "page1",
            jwtToken: "jwt1"
        )
        let params = sut.getEventParams(eventRequest)
        XCTAssertEqual(params["sessionId"] as? String, "session1")
        XCTAssertEqual((params["attributes"] as? [[String: Any]])?.first?["name"] as? String, "dataKey")
        XCTAssertEqual((params["attributes"] as? [[String: Any]])?.first?["value"] as? String, "dataValue")
        XCTAssertNil((params["eventData"] as? [[String: Any]]))
    }

    func test_GetEventParams_empty() {
        let eventRequest = RoktEventRequest(
            sessionId: "session1",
            eventType: .SignalImpression,
            parentGuid: "parent1",
            pageInstanceGuid: "page1",
            jwtToken: "jwt1"
        )
        let params = sut.getEventParams(eventRequest)
        XCTAssertEqual(params["sessionId"] as? String, "session1")
        XCTAssertTrue((params["attributes"] as? [[String: Any]])?.isEmpty == true)
        XCTAssertNil(params["eventData"] as? [[String: Any]])
    }

    // MARK: - ProcessTimingRequests Tests

    func test_processTimingRequests_WithValidEvent() {
        // Arrange
        let mockTimingsRequestProcessor = MockTimingsRequestProcessor()
        let originalShared = Rokt.shared.roktImplementation
        let executeId = "execute1"

        // Configure Rokt.shared with mock
        Rokt.shared.roktImplementation.processedTimingsRequests = mockTimingsRequestProcessor

        // Create test data - SignalImpression with BE_PAGE_SIGNAL_LOAD metadata, pluginId, and pluginName
        let metadata = [
            RoktEventNameValue(name: Rokt_Widget.BE_PAGE_SIGNAL_LOAD, value: "2023-01-01T12:00:00.000Z"),
            RoktEventNameValue(name: Rokt_Widget.BE_TIMINGS_PLUGIN_ID_KEY, value: "test-plugin-id"),
            RoktEventNameValue(name: Rokt_Widget.BE_TIMINGS_PLUGIN_NAME_KEY, value: "test-plugin-name")
        ]

        let eventRequest = RoktEventRequest(
            sessionId: "session1",
            eventType: .SignalImpression,
            parentGuid: "parent1",
            extraMetadata: metadata,
            pageInstanceGuid: "page1",
            jwtToken: "jwt1"
        )

        // Act
        sut.process(createPayload([eventRequest]), executeId: executeId, cacheProperties: nil)

        // Assert
        XCTAssertTrue(mockTimingsRequestProcessor.setPlacementInteractiveCalled)
        XCTAssertTrue(mockTimingsRequestProcessor.setPluginAttributesCalled)
        XCTAssertTrue(mockTimingsRequestProcessor.processTimingsRequestCalled)
        XCTAssertEqual(mockTimingsRequestProcessor.lastSelectionId, executeId)
        XCTAssertEqual(mockTimingsRequestProcessor.lastPluginId, "test-plugin-id")
        XCTAssertEqual(mockTimingsRequestProcessor.lastPluginName, "test-plugin-name")

        // Cleanup
        Rokt.shared.roktImplementation.processedTimingsRequests = originalShared.processedTimingsRequests
    }

    func test_processTimingRequests_WithWrongEventType() {
        // Arrange
        let mockTimingsRequestProcessor = MockTimingsRequestProcessor()
        let originalShared = Rokt.shared.roktImplementation
        let testSelectionId = "test-selection-id"

        // Configure Rokt.shared with mock
        Rokt.shared.roktImplementation.processedTimingsRequests = mockTimingsRequestProcessor
        mockStateManager.mockSelectionId = testSelectionId

        // Create test data - SignalDismissal (wrong type) with BE_PAGE_SIGNAL_LOAD metadata and pluginId
        let metadata = [
            RoktEventNameValue(name: Rokt_Widget.BE_PAGE_SIGNAL_LOAD, value: "2023-01-01T12:00:00.000Z"),
            RoktEventNameValue(name: Rokt_Widget.BE_TIMINGS_PLUGIN_ID_KEY, value: "test-plugin-id")
        ]

        let eventRequest = RoktEventRequest(
            sessionId: "session1",
            eventType: .SignalDismissal, // Wrong event type
            parentGuid: "parent1",
            extraMetadata: metadata,
            pageInstanceGuid: "page1",
            jwtToken: "jwt1"
        )

        // Act
        sut.process(createPayload([eventRequest]), executeId: "execute1", cacheProperties: nil)

        // Assert
        XCTAssertFalse(mockTimingsRequestProcessor.processTimingsRequestCalled)

        // Cleanup
        Rokt.shared.roktImplementation.processedTimingsRequests = originalShared.processedTimingsRequests
    }

    func test_processTimingRequests_WithMissingSignalLoad() {
        // Arrange
        let mockTimingsRequestProcessor = MockTimingsRequestProcessor()
        let originalShared = Rokt.shared.roktImplementation
        let testSelectionId = "test-selection-id"

        // Configure Rokt.shared with mock
        Rokt.shared.roktImplementation.processedTimingsRequests = mockTimingsRequestProcessor
        mockStateManager.mockSelectionId = testSelectionId

        // Create test data - SignalImpression but missing BE_PAGE_SIGNAL_LOAD metadata
        let metadata = [
            RoktEventNameValue(name: Rokt_Widget.BE_TIMINGS_PLUGIN_ID_KEY, value: "test-plugin-id")
        ]

        let eventRequest = RoktEventRequest(
            sessionId: "session1",
            eventType: .SignalImpression,
            parentGuid: "parent1",
            extraMetadata: metadata,
            pageInstanceGuid: "page1",
            jwtToken: "jwt1"
        )

        // Act
        sut.process(createPayload([eventRequest]), executeId: "execute1", cacheProperties: nil)

        // Assert
        XCTAssertFalse(mockTimingsRequestProcessor.processTimingsRequestCalled)

        // Cleanup
        Rokt.shared.roktImplementation.processedTimingsRequests = originalShared.processedTimingsRequests
    }

    func test_processTimingRequests_WithMissingPluginId() throws {
        // Arrange
        let mockTimingsRequestProcessor = MockTimingsRequestProcessor()
        let originalShared = Rokt.shared.roktImplementation
        let testSelectionId = "test-selection-id"

        // Configure Rokt.shared with mock
        Rokt.shared.roktImplementation.processedTimingsRequests = mockTimingsRequestProcessor
        mockStateManager.mockSelectionId = testSelectionId

        // Create test data - SignalImpression with BE_PAGE_SIGNAL_LOAD but missing pluginId
        let metadata = [
            RoktEventNameValue(name: Rokt_Widget.BE_PAGE_SIGNAL_LOAD, value: "2023-01-01T12:00:00.000Z")
            // Missing BE_TIMINGS_PLUGIN_ID_KEY
        ]

        let eventRequest = RoktEventRequest(
            sessionId: "session1",
            eventType: .SignalImpression,
            parentGuid: "parent1",
            extraMetadata: metadata,
            pageInstanceGuid: "page1",
            jwtToken: "jwt1"
        )

        // Act
        sut.process(createPayload([eventRequest]), executeId: "execute1", cacheProperties: nil)

        // Assert
        XCTAssertFalse(mockTimingsRequestProcessor.processTimingsRequestCalled)

        // Cleanup
        Rokt.shared.roktImplementation.processedTimingsRequests = originalShared.processedTimingsRequests
    }

    func test_processTimingRequests_WithMultipleEvents() {
        // Arrange
        let mockTimingsRequestProcessor = MockTimingsRequestProcessor()
        let originalShared = Rokt.shared.roktImplementation
        let testSelectionId = "test-selection-id"

        // Configure Rokt.shared with mock
        Rokt.shared.roktImplementation.processedTimingsRequests = mockTimingsRequestProcessor
        mockStateManager.mockSelectionId = testSelectionId

        // Create valid event
        let validMetadata = [
            RoktEventNameValue(name: Rokt_Widget.BE_PAGE_SIGNAL_LOAD, value: "2023-01-01T12:00:00.000Z"),
            RoktEventNameValue(name: Rokt_Widget.BE_TIMINGS_PLUGIN_ID_KEY, value: "test-plugin-id"),
            RoktEventNameValue(name: Rokt_Widget.BE_TIMINGS_PLUGIN_NAME_KEY, value: "test-plugin-name")
        ]

        let validEvent = RoktEventRequest(
            sessionId: "session1",
            eventType: .SignalImpression,
            parentGuid: "parent1",
            extraMetadata: validMetadata,
            pageInstanceGuid: "page1",
            jwtToken: "jwt1"
        )

        // Create invalid event (wrong type)
        let invalidEvent = RoktEventRequest(
            sessionId: "session2",
            eventType: .SignalLoadStart,
            parentGuid: "parent2",
            extraMetadata: validMetadata,
            pageInstanceGuid: "page2",
            jwtToken: "jwt2"
        )

        // Act with both events
        sut.process(createPayload([validEvent, invalidEvent]),
                    executeId: "execute1",
                    cacheProperties: nil)

        // Assert - only the valid event should have been processed
        XCTAssertTrue(mockTimingsRequestProcessor.processTimingsRequestCalled)
        XCTAssertEqual(mockTimingsRequestProcessor.lastPluginId, "test-plugin-id")
        XCTAssertEqual(mockTimingsRequestProcessor.lastPluginName, "test-plugin-name")
        XCTAssertEqual(mockTimingsRequestProcessor.receivedEvents, 1)
        // Cleanup
        Rokt.shared.roktImplementation.processedTimingsRequests = originalShared.processedTimingsRequests
    }

    func test_processTimingRequests_WithPluginName() {
        // Arrange
        let mockTimingsRequestProcessor = MockTimingsRequestProcessor()
        let originalShared = Rokt.shared.roktImplementation
        let testSelectionId = "test-selection-id"

        // Configure Rokt.shared with mock
        Rokt.shared.roktImplementation.processedTimingsRequests = mockTimingsRequestProcessor
        mockStateManager.mockSelectionId = testSelectionId

        // Create test data with plugin name
        let metadata = [
            RoktEventNameValue(name: Rokt_Widget.BE_PAGE_SIGNAL_LOAD, value: "2023-01-01T12:00:00.000Z"),
            RoktEventNameValue(name: Rokt_Widget.BE_TIMINGS_PLUGIN_ID_KEY, value: "test-plugin-id"),
            RoktEventNameValue(name: Rokt_Widget.BE_TIMINGS_PLUGIN_NAME_KEY, value: "TestPluginName")
        ]

        let eventRequest = RoktEventRequest(
            sessionId: "session1",
            eventType: .SignalImpression,
            parentGuid: "parent1",
            extraMetadata: metadata,
            pageInstanceGuid: "page1",
            jwtToken: "jwt1"
        )

        // Act
        sut.process(createPayload([eventRequest]), executeId: "execute1", cacheProperties: nil)

        // Assert
        XCTAssertTrue(mockTimingsRequestProcessor.setPluginAttributesCalled)
        XCTAssertEqual(mockTimingsRequestProcessor.lastPluginId, "test-plugin-id")
        XCTAssertEqual(mockTimingsRequestProcessor.lastPluginName, "TestPluginName")

        // Cleanup
        Rokt.shared.roktImplementation.processedTimingsRequests = originalShared.processedTimingsRequests
    }

    func test_processTimingRequests_WithoutPluginName() {
        // Arrange
        let mockTimingsRequestProcessor = MockTimingsRequestProcessor()
        let originalShared = Rokt.shared.roktImplementation
        let testSelectionId = "test-selection-id"

        // Configure Rokt.shared with mock
        Rokt.shared.roktImplementation.processedTimingsRequests = mockTimingsRequestProcessor
        mockStateManager.mockSelectionId = testSelectionId

        // Create test data without plugin name
        let metadata = [
            RoktEventNameValue(name: Rokt_Widget.BE_PAGE_SIGNAL_LOAD, value: "2023-01-01T12:00:00.000Z"),
            RoktEventNameValue(name: Rokt_Widget.BE_TIMINGS_PLUGIN_ID_KEY, value: "test-plugin-id")
            // No BE_TIMINGS_PLUGIN_NAME_KEY
        ]

        let eventRequest = RoktEventRequest(
            sessionId: "session1",
            eventType: .SignalImpression,
            parentGuid: "parent1",
            extraMetadata: metadata,
            pageInstanceGuid: "page1",
            jwtToken: "jwt1"
        )

        // Act
        sut.process(createPayload([eventRequest]), executeId: "execute1", cacheProperties: nil)

        // Assert - should still work with nil plugin name
        XCTAssertTrue(mockTimingsRequestProcessor.processTimingsRequestCalled)
        XCTAssertEqual(mockTimingsRequestProcessor.lastPluginId, "test-plugin-id")
        XCTAssertNil(mockTimingsRequestProcessor.lastPluginName)

        // Cleanup
        Rokt.shared.roktImplementation.processedTimingsRequests = originalShared.processedTimingsRequests
    }

    private func createPayload(_ events: [RoktEventRequest]) -> [String: Any] {
        ["events": events.map(\.getParams)]
            .merging(RoktIntegrationInfo.shared.json, uniquingKeysWith: { new, _ in new })
    }

    private func mockEventsPayload(events: [RoktEventRequest]) -> [String: Any]? {
        let payload = RoktUXEventsPayload(events: events)
        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }
}

private class MockTimingsRequestProcessor: TimingsRequestProcessor {
    var processTimingsRequestCalled = false
    var setPlacementInteractiveCalled = false
    var setPluginAttributesCalled = false
    var lastSelectionId: String?
    var lastPluginId: String?
    var lastPluginName: String?
    var receivedEvents = 0

    override func setPlacementInteractiveTime(selectionId: String, _ time: Date?) {
        setPlacementInteractiveCalled = true
        lastSelectionId = selectionId
        super.setPlacementInteractiveTime(selectionId: selectionId, time)
    }

    override func setPluginAttributes(selectionId: String, pluginId: String?, pluginName: String?) {
        setPluginAttributesCalled = true
        lastSelectionId = selectionId
        lastPluginId = pluginId
        lastPluginName = pluginName
        super.setPluginAttributes(selectionId: selectionId, pluginId: pluginId, pluginName: pluginName)
    }

    override func processTimingsRequest(selectionId: String) {
        processTimingsRequestCalled = true
        lastSelectionId = selectionId
        receivedEvents += 1
    }
}

private class MockStateManager: StateBagManaging {
    var mockSelectionId: String?

    func addState(id: String, state: any Bag) {}
    func removeState(id: String) {}
    func getState(id: String) -> (any Bag)? {
        if mockSelectionId != nil {
            return ExecuteStateBag(
                uxHelper: nil,
                onRoktEvent: nil
            )
        }
        return nil
    }
    func increasePlacements(id: String) {}
    func decreasePlacements(id: String) {}
    func find(where: (any Bag) -> Bool) -> (any Bag)? { nil }

    var stateIdRetrieved: String?
    var initiateInstantPurchaseCalled = false
    func initiateInstantPurchase(id: String) {
        stateIdRetrieved = id
        initiateInstantPurchaseCalled = true
    }

    var finishInstantPurchaseCalled = false
    func finishInstantPurchase(id: String) {
        stateIdRetrieved = id
        finishInstantPurchaseCalled = true
    }
}
