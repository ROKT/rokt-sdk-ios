import Foundation
internal import RoktUXHelper

class TimingsRequestProcessor {
    // Store timing data per selectionId to support concurrent execute calls
    private var timingDataMap: [String: TimingData] = [:]

    // Init timings are global, not per-selection
    private var initStartTime: Date?
    private var initEndTime: Date?

    private var processedTimingsRequests = ThreadSafeSet<ProcessedTimingsRequest>()
    private var apiHelper: RoktAPIHelper.Type

    init(apiHelper: RoktAPIHelper.Type = RoktAPIHelper.self) {
        self.apiHelper = apiHelper
    }

    /// Retrieves or creates TimingData for a given selectionId
    private func getOrCreateTimingData(selectionId: String) -> TimingData {
        if let existingData = timingDataMap[selectionId] {
            return existingData
        }
        let newData = TimingData()
        timingDataMap[selectionId] = newData
        return newData
    }

    func setInitStartTime(_ time: Date? = RoktSDKDateHandler.currentDate()) {
        self.initStartTime = time
    }

    func setInitEndTime() {
        self.initEndTime = RoktSDKDateHandler.currentDate()
    }

    func setPageProperties(selectionId: String, sessionId: String, pageId: String?, pageInstanceGuid: String?) {
        let timingData = getOrCreateTimingData(selectionId: selectionId)
        timingData.sessionId = sessionId
        timingData.pageId = pageId
        timingData.pageInstanceGuid = pageInstanceGuid
    }

    func getValidPageInitTime(selectionId: String, timeAsString: String) -> Date? {
        // Validates format
        guard timeAsString.count == 13,
              let timeAsDouble = Double(timeAsString)
        else {
            return nil
        }

        let timeAsDate = Date(timeIntervalSince1970: (timeAsDouble/1000.0))

        let timingData = getOrCreateTimingData(selectionId: selectionId)

        // Check date within valid range
        guard let selectionStartTime = timingData.selectionStart,
              timeAsDate.isBefore(selectionStartTime)
        else {
            return nil
        }

        return timeAsDate
    }

    func setPageInitTime(selectionId: String, time: Date? = RoktSDKDateHandler.currentDate()) {
        let timingData = getOrCreateTimingData(selectionId: selectionId)
        timingData.pageInit = time
    }

    func setSelectionStartTime(selectionId: String) {
        let timingData = getOrCreateTimingData(selectionId: selectionId)
        timingData.selectionStart = RoktSDKDateHandler.currentDate()
    }

    func setSelectionEndTime(selectionId: String) {
        let timingData = getOrCreateTimingData(selectionId: selectionId)
        timingData.selectionEnd = RoktSDKDateHandler.currentDate()
    }

    func setExperiencesRequestStartTime(selectionId: String) {
        let timingData = getOrCreateTimingData(selectionId: selectionId)
        timingData.experiencesRequestStart = RoktSDKDateHandler.currentDate()
    }

    func setExperiencesRequestEndTime(selectionId: String) {
        let timingData = getOrCreateTimingData(selectionId: selectionId)
        timingData.experiencesRequestEnd = RoktSDKDateHandler.currentDate()
    }

    func setPlacementInteractiveTime(selectionId: String, _ time: Date? = RoktSDKDateHandler.currentDate()) {
        let timingData = getOrCreateTimingData(selectionId: selectionId)
        timingData.placementInteractive = time
    }

    func setJointSdkSelectPlacements(selectionId: String, timestamp: Int64) {
        let timingData = getOrCreateTimingData(selectionId: selectionId)
        timingData.jointSdkSelectPlacements = Date(timeIntervalSince1970: Double(timestamp)/1000.0)
    }

    func setPluginAttributes(selectionId: String, pluginId: String?, pluginName: String?) {
        let timingData = getOrCreateTimingData(selectionId: selectionId)
        timingData.pluginId = pluginId
        timingData.pluginName = pluginName
    }

    /// Processes and sends timing request for the given selectionId
    /// This should only be called when placementInteractive event is triggered
    func processTimingsRequest(selectionId: String) {
        guard let timingData = timingDataMap[selectionId] else {
            return
        }

        // Only send timings for non-cached experiences (where experiencesRequestStart was set)
        // Cache hits skip the network request, so experiencesRequestStart remains nil
        guard timingData.experiencesRequestStart != nil else {
            return
        }

        let timingsRequest = buildTimingsRequest(timingData: timingData)
        if isUniqueTimingsRequest(timingsRequest) {
            apiHelper.sendTimings(timingsRequest, sessionId: timingData.sessionId, selectionId: selectionId)
        }
    }

    /// Resets timing data for a specific selectionId
    func resetPageTimings(selectionId: String) {
        let timingData = getOrCreateTimingData(selectionId: selectionId)
        timingData.experiencesRequestStart = nil
        timingData.experiencesRequestEnd = nil
        timingData.selectionStart = nil
        timingData.selectionEnd = nil
        timingData.pageInit = nil
        timingData.placementInteractive = nil
        timingData.jointSdkSelectPlacements = nil
    }

    private func buildTimingsRequest(timingData: TimingData) -> TimingsRequest {
        return TimingsRequest(pageId: timingData.pageId,
                              pageInstanceGuid: timingData.pageInstanceGuid,
                              pluginId: timingData.pluginId,
                              pluginName: timingData.pluginName,
                              timings: buildTimingMetricArray(timingData))
    }

    private func isUniqueTimingsRequest(_ req: TimingsRequest) -> Bool {
        // Checks if unique timings request (unique per execute or plugin)
        let pendingEvent = ProcessedTimingsRequest(pageInstanceGuid: req.pageInstanceGuid)
        return processedTimingsRequests.insert(pendingEvent).inserted
    }

    private func buildTimingMetricArray(_ timingData: TimingData) -> [TimingMetric] {
        var timingsMetrics = [TimingMetric]()

        if let initStartValue = self.initStartTime {
            timingsMetrics.append(TimingMetric(name: .initStart, value: initStartValue))
        }
        if let initEndValue = self.initEndTime {
            timingsMetrics.append(TimingMetric(name: .initEnd, value: initEndValue))
        }
        if let pageInitValue = timingData.pageInit {
            timingsMetrics.append(TimingMetric(name: .pageInit, value: pageInitValue))
        }
        if let selectionStartValue = timingData.selectionStart {
            timingsMetrics.append(TimingMetric(name: .selectionStart, value: selectionStartValue))
        }
        if let experiencesRequestStartValue = timingData.experiencesRequestStart {
            timingsMetrics.append(
                TimingMetric(name: .experiencesRequestStart, value: experiencesRequestStartValue)
            )
        }
        if let experiencesRequestEndValue = timingData.experiencesRequestEnd {
            timingsMetrics.append(
                TimingMetric(name: .experiencesRequestEnd, value: experiencesRequestEndValue)
            )
        }
        if let selectionEndValue = timingData.selectionEnd {
            timingsMetrics.append(TimingMetric(name: .selectionEnd, value: selectionEndValue))
        }
        if let placementInteractiveValue = timingData.placementInteractive {
            timingsMetrics.append(
                TimingMetric(name: .placementInteractive, value: placementInteractiveValue)
            )
        }
        if let jointSdkSelectPlacementsValue = timingData.jointSdkSelectPlacements {
            timingsMetrics.append(
                TimingMetric(name: .jointSdkSelectPlacements, value: jointSdkSelectPlacementsValue)
            )
        }

        return timingsMetrics
    }
}
