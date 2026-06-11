import Foundation

/// Request body for `v1/timings/events`: the performance `timingMetrics` the SDK sends
/// (experiences-request latency and experience JSON-parse duration).
class TimingEventsRequest: Codable {
    static let timingMetricsKey = "timingMetrics"

    let pageId: String?
    let pageInstanceGuid: String?
    let pluginId: String?
    let pluginName: String?
    let timings: [TimingMetric]

    init(pageId: String? = nil,
         pageInstanceGuid: String? = nil,
         pluginId: String? = nil,
         pluginName: String? = nil,
         timings: [TimingMetric]) {
        self.pageId = pageId
        self.pageInstanceGuid = pageInstanceGuid
        self.pluginId = pluginId
        self.pluginName = pluginName
        self.timings = timings
    }

    internal func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
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
