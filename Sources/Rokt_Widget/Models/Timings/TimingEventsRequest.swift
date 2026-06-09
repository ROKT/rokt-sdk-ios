import Foundation

/// Request payload for the `v1/timings/events` endpoint, carrying performance
/// metrics (experiences request latency and experience JSON parse duration).
class TimingEventsRequest: Codable {
    static let timingMetricsKey = "timingMetrics"
    private static let isCachedKey = "isCached"
    private static let expectedTtiKey = "expectedTti"

    let eventTime: Date
    let isCached: Bool
    let expectedTti: Int64
    let pageId: String?
    let pageInstanceGuid: String?
    let pluginId: String?
    let pluginName: String?
    let timings: [TimingMetric]

    init(eventTime: Date = RoktSDKDateHandler.currentDate(),
         isCached: Bool = false,
         expectedTti: Int64 = 0,
         pageId: String? = nil,
         pageInstanceGuid: String? = nil,
         pluginId: String? = nil,
         pluginName: String? = nil,
         timings: [TimingMetric]) {
        self.eventTime = eventTime
        self.isCached = isCached
        self.expectedTti = expectedTti
        self.pageId = pageId
        self.pageInstanceGuid = pageInstanceGuid
        self.pluginId = pluginId
        self.pluginName = pluginName
        self.timings = timings
    }

    internal func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            timingsEventTimeKey: EventDateFormatter.getDateString(self.eventTime),
            Self.isCachedKey: isCached,
            Self.expectedTtiKey: expectedTti,
            Self.timingMetricsKey: timings.map { $0.toDictionary() }
        ]

        if let pluginId = self.pluginId {
            dict[timingsPluginIdKey] = pluginId
        }
        if let pluginName = self.pluginName {
            dict[timingsPluginNameKey] = pluginName
        }

        return dict
    }
}
