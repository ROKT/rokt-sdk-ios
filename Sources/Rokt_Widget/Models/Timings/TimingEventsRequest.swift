import Foundation

/// Request payload for the `v1/timings/events` endpoint, carrying performance
/// metrics (experiences request latency and experience JSON parse duration).
///
/// The mobile SDK sends only the fields the backend actually consumes for an
/// `msdk` event: the `timingMetrics` array (the sole required body field) plus the
/// optional plugin attributes used for downstream segmentation. Fields that the
/// endpoint exposes purely for the web SDK — or that the backend overwrites — are
/// intentionally omitted to keep the payload minimal:
///   - `eventTime`   — overwritten server-side with the receive time, body value dropped.
///   - `isCached`    — a WSDK concept (browser static-asset cache); always false here
///                     since cache hits never reach this endpoint.
///   - `expectedTti` — a WSDK time-to-interactive metric; not applicable to mobile.
///
/// `pageId` / `pageInstanceGuid` are carried on the model only to populate request
/// headers (`rokt-page-id` / `rokt-page-instance-guid`); they are not part of the body.
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
