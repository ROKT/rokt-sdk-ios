import XCTest
@testable import Rokt_Widget
@testable internal import RoktUXHelper

class TestTimingsRequestProcessor: XCTestCase {

    var sut: TimingsRequestProcessor!
    var fixedDate: Date!
    var testSelectionId: String!

    override func setUp() {
        super.setUp()

        // Setup a fixed date for predictable testing
        fixedDate = Date(timeIntervalSince1970: 1600000000) // September 13, 2020 12:26:40 GMT
        RoktSDKDateHandler.customDate = fixedDate

        // Generate a test selectionId
        testSelectionId = UUID().uuidString

        // Initialize the system under test
        sut = TimingsRequestProcessor(apiHelper: RoktAPIHelperSpy.self)
    }

    override func tearDown() {
        sut = nil
        RoktAPIHelperSpy.reset()
        RoktSDKDateHandler.customDate = nil
        super.tearDown()
    }

    // MARK: - Tests for setting properties

    func testSetPageProperties() {
        // Arrange
        let pageId = "test_page_id"
        let pageInstanceGuid = "test_page_instance_guid"
        let sessionId = "test_session_id"

        // Act
        sut.setPageProperties(
            selectionId: testSelectionId,
            sessionId: sessionId,
            pageId: pageId,
            pageInstanceGuid: pageInstanceGuid
        )

        // Assert
        sut.setExperiencesRequestStartTime(selectionId: testSelectionId)
        sut.setPlacementInteractiveTime(selectionId: testSelectionId)
        sut.processTimingsRequest(selectionId: testSelectionId)
        let timingsRequest = RoktAPIHelperSpy.lastTimingsRequest
        XCTAssertEqual(timingsRequest?.pageId, pageId)
        XCTAssertEqual(timingsRequest?.pageInstanceGuid, pageInstanceGuid)
        XCTAssertEqual(RoktAPIHelperSpy.lastSessionId, sessionId)
    }

    func testSetInitStartTime() {
        // Act
        sut.setInitStartTime()

        // Assert
        sut.setExperiencesRequestStartTime(selectionId: testSelectionId)
        sut.setPlacementInteractiveTime(selectionId: testSelectionId)
        sut.processTimingsRequest(selectionId: testSelectionId)
        let timingsRequest = RoktAPIHelperSpy.lastTimingsRequest!
        XCTAssertTrue(containsTimingMetric(timingsRequest.timings, name: .initStart, value: fixedDate))
    }

    func testSetInitEndTime() {
        // Act
        sut.setInitEndTime()

        // Assert
        sut.setExperiencesRequestStartTime(selectionId: testSelectionId)
        sut.setPlacementInteractiveTime(selectionId: testSelectionId)
        sut.processTimingsRequest(selectionId: testSelectionId)
        let timingsRequest = RoktAPIHelperSpy.lastTimingsRequest!
        XCTAssertTrue(containsTimingMetric(timingsRequest.timings, name: .initEnd, value: fixedDate))
    }

    func testSetPageInitTime() {
        // Act
        sut.setPageInitTime(selectionId: testSelectionId)

        // Assert
        sut.setExperiencesRequestStartTime(selectionId: testSelectionId)
        sut.setPlacementInteractiveTime(selectionId: testSelectionId)
        sut.processTimingsRequest(selectionId: testSelectionId)
        let timingsRequest = RoktAPIHelperSpy.lastTimingsRequest!
        XCTAssertTrue(containsTimingMetric(timingsRequest.timings, name: .pageInit, value: fixedDate))
    }

    func testSetSelectionStartTime() {
        // Act
        sut.setSelectionStartTime(selectionId: testSelectionId)

        // Assert
        sut.setExperiencesRequestStartTime(selectionId: testSelectionId)
        sut.setPlacementInteractiveTime(selectionId: testSelectionId)
        sut.processTimingsRequest(selectionId: testSelectionId)
        let timingsRequest = RoktAPIHelperSpy.lastTimingsRequest!
        XCTAssertTrue(containsTimingMetric(timingsRequest.timings, name: .selectionStart, value: fixedDate))
    }

    func testSetSelectionEndTime() {
        // Act
        sut.setSelectionEndTime(selectionId: testSelectionId)

        // Assert
        sut.setExperiencesRequestStartTime(selectionId: testSelectionId)
        sut.setPlacementInteractiveTime(selectionId: testSelectionId)
        sut.processTimingsRequest(selectionId: testSelectionId)
        let timingsRequest = RoktAPIHelperSpy.lastTimingsRequest!
        XCTAssertTrue(containsTimingMetric(timingsRequest.timings, name: .selectionEnd, value: fixedDate))
    }

    func testSetExperiencesRequestStartTime() {
        // Act
        sut.setExperiencesRequestStartTime(selectionId: testSelectionId)

        // Assert
        sut.setPlacementInteractiveTime(selectionId: testSelectionId)
        sut.processTimingsRequest(selectionId: testSelectionId)
        let timingsRequest = RoktAPIHelperSpy.lastTimingsRequest!
        XCTAssertTrue(containsTimingMetric(timingsRequest.timings, name: .experiencesRequestStart, value: fixedDate))
    }

    func testSetExperiencesRequestEndTime() {
        // Act
        sut.setExperiencesRequestEndTime(selectionId: testSelectionId)

        // Assert
        sut.setExperiencesRequestStartTime(selectionId: testSelectionId)
        sut.setPlacementInteractiveTime(selectionId: testSelectionId)
        sut.processTimingsRequest(selectionId: testSelectionId)
        let timingsRequest = RoktAPIHelperSpy.lastTimingsRequest!
        XCTAssertTrue(containsTimingMetric(timingsRequest.timings, name: .experiencesRequestEnd, value: fixedDate))
    }

    func testSetPlacementInteractiveTime() {
        // Act
        sut.setPlacementInteractiveTime(selectionId: testSelectionId)

        // Assert
        sut.setExperiencesRequestStartTime(selectionId: testSelectionId)
        sut.processTimingsRequest(selectionId: testSelectionId)
        let timingsRequest = RoktAPIHelperSpy.lastTimingsRequest!
        XCTAssertTrue(containsTimingMetric(timingsRequest.timings, name: .placementInteractive, value: fixedDate))
    }

    func testSetJointSdkSelectPlacements() {
        // Arrange
        let jointSdkTimestamp: Int64 = 1600000100000

        // Act
        sut.setJointSdkSelectPlacements(selectionId: testSelectionId, timestamp: jointSdkTimestamp)

        // Assert
        sut.setExperiencesRequestStartTime(selectionId: testSelectionId)
        sut.setPlacementInteractiveTime(selectionId: testSelectionId)
        sut.processTimingsRequest(selectionId: testSelectionId)
        let timingsRequest = RoktAPIHelperSpy.lastTimingsRequest!
        let expectedDate = Date(timeIntervalSince1970: Double(jointSdkTimestamp)/1000.0)
        XCTAssertTrue(containsTimingMetric(timingsRequest.timings, name: .jointSdkSelectPlacements, value: expectedDate))
    }

    func testJointSdkSelectPlacements_NotIncludedWhenNotSet() {
        // Act - Don't set jointSdkSelectPlacements
        sut.setExperiencesRequestStartTime(selectionId: testSelectionId)
        sut.setPlacementInteractiveTime(selectionId: testSelectionId)
        sut.processTimingsRequest(selectionId: testSelectionId)

        // Assert
        let timingsRequest = RoktAPIHelperSpy.lastTimingsRequest!
        let hasJointSdkMetric = timingsRequest.timings.contains { $0.name == .jointSdkSelectPlacements }
        XCTAssertFalse(hasJointSdkMetric)
    }

    func testJointSdkSelectPlacements_ResetWithPageTimings() {
        // Arrange
        let jointSdkTimestamp: Int64 = 1600000100000
        sut.setJointSdkSelectPlacements(selectionId: testSelectionId, timestamp: jointSdkTimestamp)
        sut.setExperiencesRequestStartTime(selectionId: testSelectionId)
        sut.setPlacementInteractiveTime(selectionId: testSelectionId)
        sut.setPageProperties(selectionId: testSelectionId, sessionId: "session1", pageId: "page1",
                              pageInstanceGuid: "guid1")
        sut.processTimingsRequest(selectionId: testSelectionId)

        // Verify it was included before reset
        let timingsRequestBeforeReset = RoktAPIHelperSpy.lastTimingsRequest!
        XCTAssertTrue(timingsRequestBeforeReset.timings.contains { $0.name == .jointSdkSelectPlacements })

        // Act - Reset and process again with different pageInstanceGuid
        sut.resetPageTimings(selectionId: testSelectionId)
        RoktAPIHelperSpy.reset()
        sut.setPageProperties(selectionId: testSelectionId, sessionId: "session2", pageId: "page2",
                              pageInstanceGuid: "guid2")
        sut.setExperiencesRequestStartTime(selectionId: testSelectionId)
        sut.setPlacementInteractiveTime(selectionId: testSelectionId)
        sut.processTimingsRequest(selectionId: testSelectionId)

        // Assert - jointSdkSelectPlacements should not be included after reset
        let timingsRequestAfterReset = RoktAPIHelperSpy.lastTimingsRequest!
        let hasJointSdkMetric = timingsRequestAfterReset.timings.contains { $0.name == .jointSdkSelectPlacements }
        XCTAssertFalse(hasJointSdkMetric)
    }

    // MARK: - Tests for getValidPageInitTime

    func testGetValidPageInitTime_ValidFormat_BeforeSelectionStart() {
        // Arrange
        let tenSecondsAgo = Date(timeIntervalSince1970: fixedDate.timeIntervalSince1970 - 10)
        let timeAsString = String(Int(tenSecondsAgo.timeIntervalSince1970 * 1000))
        sut.setSelectionStartTime(selectionId: testSelectionId)

        // Act
        let result = sut.getValidPageInitTime(selectionId: testSelectionId, timeAsString: timeAsString)

        // Assert
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.timeIntervalSince1970, tenSecondsAgo.timeIntervalSince1970, accuracy: 0.001)
    }

    func testGetValidPageInitTime_ValidFormat_AfterSelectionStart() {
        // Arrange
        let tenSecondsLater = Date(timeIntervalSince1970: fixedDate.timeIntervalSince1970 + 10)
        let timeAsString = String(Int(tenSecondsLater.timeIntervalSince1970 * 1000))
        sut.setSelectionStartTime(selectionId: testSelectionId)

        // Act
        let result = sut.getValidPageInitTime(selectionId: testSelectionId, timeAsString: timeAsString)

        // Assert
        XCTAssertNil(result)
    }

    func testGetValidPageInitTime_InvalidFormat() {
        // Arrange
        let invalidTimeString = "not-a-timestamp"
        sut.setSelectionStartTime(selectionId: testSelectionId)

        // Act
        let result = sut.getValidPageInitTime(selectionId: testSelectionId, timeAsString: invalidTimeString)

        // Assert
        XCTAssertNil(result)
    }

    func testGetValidPageInitTime_NoSelectionStartTime() {
        // Arrange
        let tenSecondsAgo = Date(timeIntervalSince1970: fixedDate.timeIntervalSince1970 - 10)
        let timeAsString = String(Int(tenSecondsAgo.timeIntervalSince1970 * 1000))

        // Act
        let result = sut.getValidPageInitTime(selectionId: testSelectionId, timeAsString: timeAsString)

        // Assert
        XCTAssertNil(result)
    }

    // MARK: - Tests for processTimingsRequest

    func testProcessTimingsRequest_WithPluginId() {
        // Arrange
        let pluginId = "test_plugin_id"
        let pluginName = "test_plugin_name"

        sut.setPluginAttributes(selectionId: testSelectionId, pluginId: pluginId, pluginName: pluginName)
        sut.setPlacementInteractiveTime(selectionId: testSelectionId)
        sut.setExperiencesRequestStartTime(selectionId: testSelectionId)

        // Act
        sut.processTimingsRequest(selectionId: testSelectionId)

        // Assert
        XCTAssertEqual(RoktAPIHelperSpy.sendTimingsCallCount, 1)
        XCTAssertEqual(RoktAPIHelperSpy.lastTimingsRequest?.pluginId, pluginId)
        XCTAssertEqual(RoktAPIHelperSpy.lastTimingsRequest?.pluginName, pluginName)
        XCTAssertEqual(RoktAPIHelperSpy.lastSelectionId, testSelectionId)
    }

    func testProcessTimingsRequest_CachedExperience_DoesNotSendTimings() {
        // Arrange - Simulate cached experience (no network request made)
        let pluginId = "test_plugin_id"
        let pluginName = "test_plugin_name"

        // Set up timing data but WITHOUT experiencesRequestStart (cache hit scenario)
        sut.setPluginAttributes(selectionId: testSelectionId, pluginId: pluginId, pluginName: pluginName)
        sut.setSelectionStartTime(selectionId: testSelectionId)
        sut.setSelectionEndTime(selectionId: testSelectionId)
        sut.setPlacementInteractiveTime(selectionId: testSelectionId)

        // Act
        sut.processTimingsRequest(selectionId: testSelectionId)

        // Assert - No timings should be sent for cached experiences
        XCTAssertEqual(RoktAPIHelperSpy.sendTimingsCallCount, 0)
        XCTAssertNil(RoktAPIHelperSpy.lastTimingsRequest)
    }

    func testProcessTimingsRequest_NetworkRequest_SendsTimings() {
        // Arrange - Simulate network request (non-cached experience)
        let pluginId = "test_plugin_id"

        // Set up timing data WITH experiencesRequestStart (network request scenario)
        sut.setPluginAttributes(selectionId: testSelectionId, pluginId: pluginId, pluginName: nil)
        sut.setSelectionStartTime(selectionId: testSelectionId)
        sut.setExperiencesRequestStartTime(selectionId: testSelectionId) // Network request made
        sut.setExperiencesRequestEndTime(selectionId: testSelectionId)
        sut.setSelectionEndTime(selectionId: testSelectionId)
        sut.setPlacementInteractiveTime(selectionId: testSelectionId)

        // Act
        sut.processTimingsRequest(selectionId: testSelectionId)

        // Assert - Timings should be sent for network requests
        XCTAssertEqual(RoktAPIHelperSpy.sendTimingsCallCount, 1)
        XCTAssertNotNil(RoktAPIHelperSpy.lastTimingsRequest)
        XCTAssertEqual(RoktAPIHelperSpy.lastTimingsRequest?.pluginId, pluginId)
    }

    // MARK: - Tests for isUniqueTimingsRequest

    func testIsUniqueTimingsRequest_UniqueRequest() {
        // Arrange
        let pluginId = "test_plugin_id"
        sut.setPluginAttributes(selectionId: testSelectionId, pluginId: pluginId, pluginName: nil)
        sut.setExperiencesRequestStartTime(selectionId: testSelectionId)
        sut.setPlacementInteractiveTime(selectionId: testSelectionId)

        // Act - First request with this plugin ID
        sut.processTimingsRequest(selectionId: testSelectionId)

        // Assert
        XCTAssertEqual(RoktAPIHelperSpy.sendTimingsCallCount, 1)
    }

    func testIsUniqueTimingsRequest_DuplicateRequest() {
        // Arrange
        let pluginId = "test_plugin_id"
        sut.setPluginAttributes(selectionId: testSelectionId, pluginId: pluginId, pluginName: nil)
        sut.setExperiencesRequestStartTime(selectionId: testSelectionId)
        sut.setPlacementInteractiveTime(selectionId: testSelectionId)

        // Act - First request
        sut.processTimingsRequest(selectionId: testSelectionId)

        // Assert
        XCTAssertEqual(RoktAPIHelperSpy.sendTimingsCallCount, 1)

        // Act - Duplicate request with same plugin ID
        sut.processTimingsRequest(selectionId: testSelectionId)

        // Assert - Count should still be 1 as duplicate was rejected
        XCTAssertEqual(RoktAPIHelperSpy.sendTimingsCallCount, 1)
    }

    func testIsUniqueTimingsRequest_DifferentPageInstanceGuids() {
        // Arrange
        let firstPageInstanceGuid = "page_instance_1"
        let secondPageInstanceGuid = "page_instance_2"
        let selectionId1 = UUID().uuidString
        let selectionId2 = UUID().uuidString

        sut.setPageProperties(selectionId: selectionId1, sessionId: "session1", pageId: "page1",
                              pageInstanceGuid: firstPageInstanceGuid)
        sut.setExperiencesRequestStartTime(selectionId: selectionId1)
        sut.setPlacementInteractiveTime(selectionId: selectionId1)

        // Act - First request with first pageInstanceGuid
        sut.processTimingsRequest(selectionId: selectionId1)

        // Assert
        XCTAssertEqual(RoktAPIHelperSpy.sendTimingsCallCount, 1)

        // Setup second selection with different pageInstanceGuid
        sut.setPageProperties(selectionId: selectionId2, sessionId: "session2", pageId: "page2",
                              pageInstanceGuid: secondPageInstanceGuid)
        sut.setExperiencesRequestStartTime(selectionId: selectionId2)
        sut.setPlacementInteractiveTime(selectionId: selectionId2)

        // Act - Second request with different pageInstanceGuid
        sut.processTimingsRequest(selectionId: selectionId2)

        // Assert - Count should be 2 as different pageInstanceGuids are considered unique
        XCTAssertEqual(RoktAPIHelperSpy.sendTimingsCallCount, 2)
    }

    // MARK: - Tests for resetPageTimings

    func testResetPageTimings() {
        // Arrange
        let pluginId1 = "test_plugin_id_1"
        let pluginId2 = "test_plugin_id_2"
        let pageInstanceGuid1 = "page_instance_guid_1"
        let pageInstanceGuid2 = "page_instance_guid_2"
        sut.setInitStartTime()
        sut.setInitEndTime()
        sut.setPageProperties(selectionId: testSelectionId, sessionId: "session1", pageId: "page1",
                              pageInstanceGuid: pageInstanceGuid1)
        sut.setPageInitTime(selectionId: testSelectionId)
        sut.setSelectionStartTime(selectionId: testSelectionId)
        sut.setSelectionEndTime(selectionId: testSelectionId)
        sut.setExperiencesRequestStartTime(selectionId: testSelectionId)
        sut.setExperiencesRequestEndTime(selectionId: testSelectionId)
        sut.setPluginAttributes(selectionId: testSelectionId, pluginId: pluginId1, pluginName: nil)
        sut.setPlacementInteractiveTime(selectionId: testSelectionId)

        sut.processTimingsRequest(selectionId: testSelectionId)
        let initialRequest = RoktAPIHelperSpy.lastTimingsRequest!
        XCTAssertEqual(initialRequest.timings.count, 8)

        // Act
        sut.resetPageTimings(selectionId: testSelectionId)
        RoktAPIHelperSpy.reset()

        // Assert - use a different pageInstanceGuid so it's considered a unique request
        sut.setPageProperties(selectionId: testSelectionId, sessionId: "session2", pageId: "page2",
                              pageInstanceGuid: pageInstanceGuid2)
        sut.setPluginAttributes(selectionId: testSelectionId, pluginId: pluginId2, pluginName: nil)
        sut.setExperiencesRequestStartTime(selectionId: testSelectionId) // Need to set this again after reset
        sut.setPlacementInteractiveTime(selectionId: testSelectionId)
        sut.processTimingsRequest(selectionId: testSelectionId)
        let afterResetRequest = RoktAPIHelperSpy.lastTimingsRequest!
        // After reset, only init timings and newly set timings remain (init timings are global, not per-selection)
        XCTAssertEqual(afterResetRequest.timings.count, 4)
        XCTAssertEqual(afterResetRequest.timings[0], TimingMetric(name: .initStart, value: fixedDate))
        XCTAssertEqual(afterResetRequest.timings[1], TimingMetric(name: .initEnd, value: fixedDate))
        XCTAssertEqual(afterResetRequest.timings[2], TimingMetric(name: .experiencesRequestStart, value: fixedDate))
        XCTAssertEqual(afterResetRequest.timings[3], TimingMetric(name: .placementInteractive, value: fixedDate))
    }

    // MARK: - Tests for multiple selectionIds

    func testMultipleSelectionIds_IndependentTimingData() {
        // Arrange
        let selectionId1 = UUID().uuidString
        let selectionId2 = UUID().uuidString
        let pluginId1 = "test_plugin_id_1"
        let pluginId2 = "test_plugin_id_2"
        let pageInstanceGuid1 = "page_instance_guid_1"
        let pageInstanceGuid2 = "page_instance_guid_2"

        // Act - Set different timing values for each selectionId
        sut.setPageProperties(selectionId: selectionId1, sessionId: "session1", pageId: "page1",
                              pageInstanceGuid: pageInstanceGuid1)
        sut.setPluginAttributes(selectionId: selectionId1, pluginId: pluginId1, pluginName: nil)
        sut.setSelectionStartTime(selectionId: selectionId1)
        sut.setExperiencesRequestStartTime(selectionId: selectionId1)
        RoktSDKDateHandler.customDate = Date(timeIntervalSince1970: fixedDate.timeIntervalSince1970 + 10)
        sut.setPageProperties(selectionId: selectionId2, sessionId: "session2", pageId: "page2",
                              pageInstanceGuid: pageInstanceGuid2)
        sut.setPluginAttributes(selectionId: selectionId2, pluginId: pluginId2, pluginName: nil)
        sut.setSelectionStartTime(selectionId: selectionId2)
        sut.setExperiencesRequestStartTime(selectionId: selectionId2)

        // Reset date for consistency
        RoktSDKDateHandler.customDate = fixedDate

        // Set placement interactive and process for selectionId1
        sut.setPlacementInteractiveTime(selectionId: selectionId1)
        sut.processTimingsRequest(selectionId: selectionId1)

        let request1 = RoktAPIHelperSpy.lastTimingsRequest!
        XCTAssertTrue(containsTimingMetric(request1.timings, name: .selectionStart, value: fixedDate))

        // Set placement interactive and process for selectionId2
        RoktSDKDateHandler.customDate = Date(timeIntervalSince1970: fixedDate.timeIntervalSince1970 + 10)
        sut.setPlacementInteractiveTime(selectionId: selectionId2)
        RoktAPIHelperSpy.reset()
        sut.processTimingsRequest(selectionId: selectionId2)

        let request2 = RoktAPIHelperSpy.lastTimingsRequest!
        let laterDate = Date(timeIntervalSince1970: fixedDate.timeIntervalSince1970 + 10)
        XCTAssertTrue(containsTimingMetric(request2.timings, name: .selectionStart, value: laterDate))

        // Verify they have different selection start times
        let selectionStart1 = request1.timings.first { $0.name == .selectionStart }?.value
        let selectionStart2 = request2.timings.first { $0.name == .selectionStart }?.value
        XCTAssertNotEqual(selectionStart1, selectionStart2)
    }

    // MARK: - Helper methods

    private func containsTimingMetric(_ metrics: [TimingMetric], name: TimingType, value: Date) -> Bool {
        return metrics.contains { metric in
            metric.name == name && abs(metric.value.timeIntervalSince(value)) < 0.001
        }
    }
}

// MARK: - Helper classes for testing

class RoktAPIHelperSpy: RoktAPIHelper {
    static var sendTimingsCallCount = 0
    static var lastTimingsRequest: TimingsRequest?
    static var lastSessionId: String?
    static var lastSelectionId: String?

    override static func sendTimings(_ timingsRequest: TimingsRequest, sessionId: String?, selectionId: String) {
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
