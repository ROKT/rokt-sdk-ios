import Foundation

let timingsMetricsKey = "timingMetrics"

class TimingsRequest: Codable {
    let eventTime: Date
    let pageId: String?
    let pageInstanceGuid: String?
    let pluginId: String?
    let pluginName: String?
    let timings: [TimingMetric]

    init(eventTime: Date,
         pageId: String? = nil,
         pageInstanceGuid: String? = nil,
         pluginId: String? = nil,
         pluginName: String? = nil,
         timings: [TimingMetric]) {
        self.eventTime = eventTime
        self.pageId = pageId
        self.pageInstanceGuid = pageInstanceGuid
        self.pluginId = pluginId
        self.pluginName = pluginName
        self.timings = timings
    }

    convenience init(pageId: String? = nil,
                     pageInstanceGuid: String? = nil,
                     pluginId: String? = nil,
                     pluginName: String? = nil,
                     timings: [TimingMetric]) {
        // Shortcut initialiser that sets eventTime current date
        self.init(eventTime: RoktSDKDateHandler.currentDate(),
                  pageId: pageId,
                  pageInstanceGuid: pageInstanceGuid,
                  pluginId: pluginId,
                  pluginName: pluginName,
                  timings: timings)
    }

    internal func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            timingsEventTimeKey: EventDateFormatter.getDateString(self.eventTime),
            timingsMetricsKey: timings.map { $0.toDictionary() }
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
