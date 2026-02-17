import Foundation
import UIKit

extension RoktAPIHelper {
    /// Extracts all privacy control KVPs from the partner's attributes
    /// - Parameter attributes: a hashmap of additional information sent by the partner
    /// - Returns: a hashmap of all privacy KVP sent by the partner
    class func getPrivacyControlPayload(attributes: [String: Any]) -> [String: Bool] {
        guard let castedAttrs = attributes as? [String: String] else { return [:] }

        return [
            kNoFunctional: castedAttrs[kNoFunctional],
            kNoTargeting: castedAttrs[kNoTargeting],
            kDoNotShareOrSell: castedAttrs[kDoNotShareOrSell],
            kGpcEnabled: castedAttrs[kGpcEnabled]
        ]
        .compactMapValues { $0 }
        .mapValues { Bool($0.lowercased()) }
        .compactMapValues { $0 }
    }

    class func getPageInitData(attributes: [String: Any]) -> String? {
        guard var castedAttrs = attributes as? [String: String] else { return nil }

        return castedAttrs.removeValue(forKey: BE_ATTRIBUTES_PAGE_INIT_KEY)
    }

    /// Removes all privacy control KVPs from partner attributes
    /// - Parameter attributes: a hashmap of additional information sent by the partner
    /// - Returns: partner `attributes` without privacy control and pageInit KVPs
    class func removePrivacyControlAttributes(attributes: [String: String]) -> [String: String] {
        var mutablePayload = attributes

        let privacyControlFields = [
            kNoFunctional,
            kNoTargeting,
            kDoNotShareOrSell,
            kGpcEnabled
        ]

        privacyControlFields.forEach { mutablePayload.removeValue(forKey: $0) }
        mutablePayload.removeValue(forKey: BE_ATTRIBUTES_PAGE_INIT_KEY)

        return mutablePayload
    }

    class func addRealtimeEventsIfPresent(to params: [String: Any]) -> [String: Any] {
        var updatedParams = params
        let BE_REALTIME_EVENTS_REQUEST_KEY = "realTimeEvents"

        let realtimeEventSource = RealTimeEventManager.shared.getTriggeredEvents()
        if !realtimeEventSource.isEmpty {
            let requestContainer = ExperienceRequestRealtimeEventsContainer(events: realtimeEventSource)

            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(requestContainer)
                if let eventsDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    updatedParams[BE_REALTIME_EVENTS_REQUEST_KEY] = eventsDict
                }
            } catch {

            }
        }
        return updatedParams
    }
}

private struct ExperienceRequestRealtimeEventsContainer: Encodable {
    let version: String = "1.0"
    let events: [TriggeredRealTimeEvent]
}
