import XCTest

@testable internal import RoktUXHelper
@testable import Rokt_Widget

/// Integration tests for timings API with selectionId support
class TestTimingsSelectionIdIntegration: XCTestCase {

    var sut: TimingsRequestProcessor!
    var fixedDate: Date!

    override func setUp() {
        super.setUp()

        fixedDate = Date(timeIntervalSince1970: 1_600_000_000)
        RoktSDKDateHandler.customDate = fixedDate
        sut = TimingsRequestProcessor(apiHelper: RoktAPIHelperIntegrationSpy.self)
        RoktAPIHelperIntegrationSpy.reset()
    }

    override func tearDown() {
        sut = nil
        RoktAPIHelperIntegrationSpy.reset()
        RoktSDKDateHandler.customDate = nil
        super.tearDown()
    }

    // MARK: - Full Execute Flow Tests

    func testFullExecuteFlow_WithPlacementInteractive_SendsTimings() {
        // Arrange - Simulate full execute flow
        // Note: In production, this is triggered by SignalImpression event with BE_PAGE_SIGNAL_LOAD
        // from RoktUXHelper which contains pluginId and pluginName in metadata
        let selectionId = UUID().uuidString
        let sessionId = "test_session_id"
        let pageId = "test_page_id"
        let pageInstanceGuid = "test_guid"
        let pluginId = "test_plugin_id"
        let pluginName = "test_plugin"

        // Act - Simulate execute lifecycle
        sut.resetPageTimings(selectionId: selectionId)
        sut.setSelectionStartTime(selectionId: selectionId)
        sut.setExperiencesRequestStartTime(selectionId: selectionId)
        sut.setExperiencesRequestEndTime(selectionId: selectionId)
        sut.setSelectionEndTime(selectionId: selectionId)
        sut.setPageProperties(
            selectionId: selectionId,
            sessionId: sessionId,
            pageId: pageId,
            pageInstanceGuid: pageInstanceGuid)

        // Simulate placement interactive event (triggered from PlatformEventProcessor)
        sut.setPlacementInteractiveTime(selectionId: selectionId)
        sut.setPluginAttributes(
            selectionId: selectionId, pluginId: pluginId, pluginName: pluginName)
        sut.processTimingsRequest(selectionId: selectionId)

        // Assert
        XCTAssertEqual(RoktAPIHelperIntegrationSpy.sendTimingsCallCount, 1)
        XCTAssertEqual(RoktAPIHelperIntegrationSpy.lastSelectionId, selectionId)
        XCTAssertEqual(RoktAPIHelperIntegrationSpy.lastSessionId, sessionId)

        let request = RoktAPIHelperIntegrationSpy.lastTimingsRequest!
        XCTAssertEqual(request.pluginId, pluginId)
        XCTAssertEqual(request.pluginName, pluginName)
        XCTAssertEqual(request.pageId, pageId)
        XCTAssertEqual(request.pageInstanceGuid, pageInstanceGuid)

        // Verify all expected timing metrics are present
        XCTAssertTrue(request.timings.contains { $0.name == .selectionStart })
        XCTAssertTrue(request.timings.contains { $0.name == .selectionEnd })
        XCTAssertTrue(request.timings.contains { $0.name == .experiencesRequestStart })
        XCTAssertTrue(request.timings.contains { $0.name == .experiencesRequestEnd })
        XCTAssertTrue(request.timings.contains { $0.name == .placementInteractive })
    }

    func testExecuteFlow_WithoutNetworkRequest_DoesNotSendTimings() {
        // Arrange - Simulate execute flow without network request (cached experience)
        let selectionId = UUID().uuidString

        // Act - Simulate execute lifecycle WITHOUT experiencesRequest (cache hit)
        sut.resetPageTimings(selectionId: selectionId)
        sut.setSelectionStartTime(selectionId: selectionId)
        // NOTE: Not calling setExperiencesRequestStartTime - indicates cache hit
        sut.setSelectionEndTime(selectionId: selectionId)

        // Even if placement becomes interactive, cached experiences shouldn't send timings
        sut.setPlacementInteractiveTime(selectionId: selectionId)
        sut.processTimingsRequest(selectionId: selectionId)

        // Assert - No timing should be sent for cached experiences
        XCTAssertEqual(RoktAPIHelperIntegrationSpy.sendTimingsCallCount, 0)
    }

    func testCachedExperience_DoesNotSendTimings() {
        // Arrange - Simulate cached experience (no network request)
        let selectionId = UUID().uuidString
        let sessionId = "test_session_id"
        let pageId = "test_page_id"
        let pageInstanceGuid = "test_guid"
        let pluginId = "test_plugin_id"
        let pluginName = "test_plugin"

        // Act - Simulate cached execute lifecycle (no experiencesRequest calls)
        sut.resetPageTimings(selectionId: selectionId)
        sut.setSelectionStartTime(selectionId: selectionId)
        // NOTE: No setExperiencesRequestStartTime - this indicates cache hit
        sut.setSelectionEndTime(selectionId: selectionId)
        sut.setPageProperties(
            selectionId: selectionId,
            sessionId: sessionId,
            pageId: pageId,
            pageInstanceGuid: pageInstanceGuid)

        // Simulate placement interactive event
        sut.setPlacementInteractiveTime(selectionId: selectionId)
        sut.setPluginAttributes(
            selectionId: selectionId, pluginId: pluginId, pluginName: pluginName)
        sut.processTimingsRequest(selectionId: selectionId)

        // Assert - No timings should be sent for cached experiences
        XCTAssertEqual(RoktAPIHelperIntegrationSpy.sendTimingsCallCount, 0)
        XCTAssertNil(RoktAPIHelperIntegrationSpy.lastTimingsRequest)
    }

    func testNetworkExperience_SendsTimings() {
        // Arrange - Simulate network experience
        let selectionId = UUID().uuidString
        let sessionId = "test_session_id"
        let pageId = "test_page_id"
        let pageInstanceGuid = "test_guid"
        let pluginId = "test_plugin_id"
        let pluginName = "test_plugin"

        // Act - Simulate network execute lifecycle (with experiencesRequest calls)
        sut.resetPageTimings(selectionId: selectionId)
        sut.setSelectionStartTime(selectionId: selectionId)
        sut.setExperiencesRequestStartTime(selectionId: selectionId) // Network request made
        sut.setExperiencesRequestEndTime(selectionId: selectionId)
        sut.setSelectionEndTime(selectionId: selectionId)
        sut.setPageProperties(
            selectionId: selectionId,
            sessionId: sessionId,
            pageId: pageId,
            pageInstanceGuid: pageInstanceGuid)

        // Simulate placement interactive event
        sut.setPlacementInteractiveTime(selectionId: selectionId)
        sut.setPluginAttributes(
            selectionId: selectionId, pluginId: pluginId, pluginName: pluginName)
        sut.processTimingsRequest(selectionId: selectionId)

        // Assert - Timings should be sent for network experiences
        XCTAssertEqual(RoktAPIHelperIntegrationSpy.sendTimingsCallCount, 1)
        XCTAssertNotNil(RoktAPIHelperIntegrationSpy.lastTimingsRequest)
        XCTAssertEqual(RoktAPIHelperIntegrationSpy.lastTimingsRequest?.pluginId, pluginId)
    }

    // MARK: - Multiple Concurrent Execute Tests

    func testMultipleConcurrentExecutes_MaintainIndependentTimings() {
        // Arrange - Multiple concurrent execute calls
        let selectionId1 = UUID().uuidString
        let selectionId2 = UUID().uuidString
        let selectionId3 = UUID().uuidString

        let sessionId1 = "session_1"
        let sessionId2 = "session_2"
        let sessionId3 = "session_3"

        // Act - Start all three executes
        sut.setSelectionStartTime(selectionId: selectionId1)
        sut.setSelectionStartTime(selectionId: selectionId2)
        sut.setSelectionStartTime(selectionId: selectionId3)

        // Advance time for selection 2
        RoktSDKDateHandler.customDate = Date(
            timeIntervalSince1970: fixedDate.timeIntervalSince1970 + 5)
        sut.setExperiencesRequestStartTime(selectionId: selectionId2)

        // Advance time for selection 3
        RoktSDKDateHandler.customDate = Date(
            timeIntervalSince1970: fixedDate.timeIntervalSince1970 + 10)
        sut.setExperiencesRequestStartTime(selectionId: selectionId3)

        // Reset time
        RoktSDKDateHandler.customDate = fixedDate
        sut.setExperiencesRequestStartTime(selectionId: selectionId1)

        // Complete all three with different timings
        sut.setPageProperties(
            selectionId: selectionId1, sessionId: sessionId1, pageId: "page1",
            pageInstanceGuid: "guid1")
        sut.setPageProperties(
            selectionId: selectionId2, sessionId: sessionId2, pageId: "page2",
            pageInstanceGuid: "guid2")
        sut.setPageProperties(
            selectionId: selectionId3, sessionId: sessionId3, pageId: "page3",
            pageInstanceGuid: "guid3")

        // Trigger placementInteractive for each
        sut.setPlacementInteractiveTime(selectionId: selectionId1)
        sut.setPluginAttributes(selectionId: selectionId1, pluginId: "plugin1", pluginName: nil)
        sut.processTimingsRequest(selectionId: selectionId1)

        XCTAssertEqual(RoktAPIHelperIntegrationSpy.lastSelectionId, selectionId1)
        let request1PageId = RoktAPIHelperIntegrationSpy.lastTimingsRequest?.pageId
        XCTAssertEqual(request1PageId, "page1")

        RoktAPIHelperIntegrationSpy.reset()

        sut.setPlacementInteractiveTime(selectionId: selectionId2)
        sut.setPluginAttributes(selectionId: selectionId2, pluginId: "plugin2", pluginName: nil)
        sut.processTimingsRequest(selectionId: selectionId2)

        XCTAssertEqual(RoktAPIHelperIntegrationSpy.lastSelectionId, selectionId2)
        let request2PageId = RoktAPIHelperIntegrationSpy.lastTimingsRequest?.pageId
        XCTAssertEqual(request2PageId, "page2")
    }

    func testConcurrentExecutes_IndependentResets() {
        // Arrange
        let selectionId1 = UUID().uuidString
        let selectionId2 = UUID().uuidString

        sut.setSelectionStartTime(selectionId: selectionId1)
        sut.setExperiencesRequestStartTime(selectionId: selectionId1)
        sut.setSelectionStartTime(selectionId: selectionId2)
        sut.setExperiencesRequestStartTime(selectionId: selectionId2)

        // Act - Reset only one
        sut.resetPageTimings(selectionId: selectionId1)

        // Assert - selectionId2 should still have its data
        sut.setPlacementInteractiveTime(selectionId: selectionId2)
        sut.processTimingsRequest(selectionId: selectionId2)

        let request = RoktAPIHelperIntegrationSpy.lastTimingsRequest!
        XCTAssertTrue(request.timings.contains { $0.name == .selectionStart })
    }

    // MARK: - x-rokt-trace-id Header Tests

    func testTimingsRequest_IncludesSelectionIdInCall() {
        // Arrange
        let selectionId = UUID().uuidString
        sut.setExperiencesRequestStartTime(selectionId: selectionId)
        sut.setPlacementInteractiveTime(selectionId: selectionId)

        // Act
        sut.processTimingsRequest(selectionId: selectionId)

        // Assert - Verify selectionId is passed to the API helper
        XCTAssertEqual(RoktAPIHelperIntegrationSpy.lastSelectionId, selectionId)
    }

    func testTimingsRequest_DifferentSelectionIds_PassedCorrectly() {
        // Arrange
        let selectionId1 = UUID().uuidString
        let selectionId2 = UUID().uuidString

        sut.setExperiencesRequestStartTime(selectionId: selectionId1)
        sut.setPlacementInteractiveTime(selectionId: selectionId1)
        sut.setPluginAttributes(selectionId: selectionId1, pluginId: "plugin1", pluginName: nil)

        // Set unique pageInstanceGuid to ensure request is unique
        sut.setPageProperties(
            selectionId: selectionId1,
            sessionId: "session1",
            pageId: "page1",
            pageInstanceGuid: "guid1")

        // Act - First request
        sut.processTimingsRequest(selectionId: selectionId1)

        // Assert
        XCTAssertEqual(RoktAPIHelperIntegrationSpy.lastSelectionId, selectionId1)

        // Act - Second request
        RoktAPIHelperIntegrationSpy.reset()
        sut.setExperiencesRequestStartTime(selectionId: selectionId2)
        sut.setPlacementInteractiveTime(selectionId: selectionId2)
        sut.setPluginAttributes(selectionId: selectionId2, pluginId: "plugin2", pluginName: nil)

        // Set unique pageInstanceGuid to ensure request is unique
        sut.setPageProperties(
            selectionId: selectionId2,
            sessionId: "session2",
            pageId: "page2",
            pageInstanceGuid: "guid2")
        sut.processTimingsRequest(selectionId: selectionId2)

        // Assert
        XCTAssertEqual(RoktAPIHelperIntegrationSpy.lastSelectionId, selectionId2)
    }

    // MARK: - Timing Lifecycle Tests

    func testCompleteTimingLifecycle_AllMetricsPresent() {
        // Arrange
        let selectionId = UUID().uuidString

        // Act - Complete lifecycle
        sut.setInitStartTime()
        sut.setInitEndTime()
        sut.resetPageTimings(selectionId: selectionId)
        sut.setPageInitTime(selectionId: selectionId)
        sut.setSelectionStartTime(selectionId: selectionId)
        sut.setExperiencesRequestStartTime(selectionId: selectionId)
        sut.setExperiencesRequestEndTime(selectionId: selectionId)
        sut.setSelectionEndTime(selectionId: selectionId)
        sut.setPlacementInteractiveTime(selectionId: selectionId)
        sut.processTimingsRequest(selectionId: selectionId)

        // Assert - All timing metrics should be present
        let request = RoktAPIHelperIntegrationSpy.lastTimingsRequest!
        XCTAssertTrue(request.timings.contains { $0.name == .initStart })
        XCTAssertTrue(request.timings.contains { $0.name == .initEnd })
        XCTAssertTrue(request.timings.contains { $0.name == .pageInit })
        XCTAssertTrue(request.timings.contains { $0.name == .selectionStart })
        XCTAssertTrue(request.timings.contains { $0.name == .selectionEnd })
        XCTAssertTrue(request.timings.contains { $0.name == .experiencesRequestStart })
        XCTAssertTrue(request.timings.contains { $0.name == .experiencesRequestEnd })
        XCTAssertTrue(request.timings.contains { $0.name == .placementInteractive })

        XCTAssertEqual(request.timings.count, 8)
    }
}

// MARK: - Helper classes for integration testing

class RoktAPIHelperIntegrationSpy: RoktAPIHelper {
    static var sendTimingsCallCount = 0
    static var lastTimingsRequest: TimingsRequest?
    static var lastSessionId: String?
    static var lastSelectionId: String?

    override static func sendTimings(
        _ timingsRequest: TimingsRequest, sessionId: String?, selectionId: String
    ) {
        sendTimingsCallCount += 1
        lastTimingsRequest = timingsRequest
        lastSessionId = sessionId
        lastSelectionId = selectionId
    }

    static func reset() {
        sendTimingsCallCount = 0
        lastTimingsRequest = nil
        lastSessionId = nil
        lastSelectionId = nil
    }
}
