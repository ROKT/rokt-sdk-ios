import Foundation
internal import RoktUXHelper

// Maps domain events to the wire event shape.
internal enum TxnEventMapper {
    private static let clientTimeStampKey = "clientTimeStamp"
    private static let captureMethodKey = "captureMethod"

    private struct MappedType {
        let eventType: String
        let markers: [String: String]

        init(_ eventType: String, _ markers: [String: String] = [:]) {
            self.eventType = eventType
            self.markers = markers
        }
    }

    static func event(from request: RoktEventRequest) -> TxnEvent? {
        guard let mapped = mappedType(for: request.eventType) else { return nil }
        return TxnEvent(
            eventType: mapped.eventType,
            instanceId: request.uuid,
            timestamp: epochMilliseconds(from: request.eventTime),
            data: buildData(
                eventType: request.eventType,
                attributes: request.eventData,
                metadata: request.metadata,
                objectData: request.objectData,
                parentGuid: request.parentGuid,
                token: request.jwtToken,
                pageInstanceGuid: request.pageInstanceGuid,
                markers: mapped.markers
            )
        )
    }

    static func event(from request: EventRequest) -> TxnEvent? {
        guard let mapped = mappedType(for: request.eventType) else { return nil }
        return TxnEvent(
            eventType: mapped.eventType,
            instanceId: request.uuid,
            timestamp: epochMilliseconds(from: request.eventTime),
            data: buildData(
                eventType: request.eventType,
                attributes: request.attributes,
                metadata: request.metadata,
                objectData: nil,
                parentGuid: request.parentGuid,
                token: request.jwtToken,
                pageInstanceGuid: request.pageInstanceGuid,
                markers: mapped.markers
            )
        )
    }

    private static func mappedType(for eventType: RoktUXEventType) -> MappedType? {
        switch eventType {
        case .SignalImpression: return MappedType("impression")
        case .SignalViewed: return MappedType("viewed")
        case .SignalInitialize: return MappedType("signal_initialize")
        case .SignalLoadStart: return MappedType("load_start")
        case .SignalLoadComplete: return MappedType("load_complete")
        case .SignalResponse: return MappedType("signal_response")
        case .SignalGatedResponse: return MappedType("signal_gated_response")
        case .SignalDismissal: return MappedType("dismissal")
        case .SignalActivation: return MappedType("user_interaction", ["interactionType": "activation"])
        case .SignalUserInteraction: return MappedType("user_interaction")
        case .CaptureAttributes: return MappedType("capture_attributes", ["sdk_event": "captureAttributes"])
        case .SignalCartItemInstantPurchaseInitiated: return MappedType("cart_item_instant_purchase_initiated")
        case .SignalCartItemInstantPurchase: return MappedType("cart_item_instant_purchase")
        case .SignalCartItemInstantPurchaseFailure: return MappedType("cart_item_instant_purchase_failure")
        case .SignalInstantPurchaseDismissal: return MappedType("instant_purchase_dismissal")
        // NOTE: a `time_on_site` wire type also exists, but there is no corresponding
        // case in RoktUXEventType in the pinned RoktUXHelper dependency, so it cannot
        // be handled here yet. See PR notes.
        default: return nil
        }
    }

    private static func buildData(
        eventType: RoktUXEventType,
        attributes: [RoktEventNameValue],
        metadata: [RoktEventNameValue],
        objectData: [String: String]?,
        parentGuid: String,
        token: String,
        pageInstanceGuid: String,
        markers: [String: String]
    ) -> [String: TxnEventDataValue]? {
        var data: [String: TxnEventDataValue] = [:]

        if eventType == .CaptureAttributes {
            // Nest under `attributes` so partner keys can't collide with top-level routing fields.
            if !attributes.isEmpty {
                var nested: [String: String] = [:]
                for item in attributes { nested[item.name] = item.value }
                data["attributes"] = .object(nested)
            }
        } else {
            for item in attributes { data[item.name] = .string(item.value) }
        }

        for item in metadata {
            switch item.name {
            case clientTimeStampKey: continue // promoted to the top-level `timestamp` field
            case captureMethodKey: data["capture_method"] = .string(item.value)
            default: data[item.name] = .string(item.value)
            }
        }

        if let objectData {
            for (key, value) in objectData { data[key] = .string(value) }
        }

        // Written last so these win over any colliding partner attribute.
        data["parent_id"] = .string(parentGuid)
        data["token"] = .string(token)
        if !pageInstanceGuid.isEmpty {
            data["page_instance_guid"] = .string(pageInstanceGuid)
        }

        for (key, value) in markers { data[key] = .string(value) }

        return data.isEmpty ? nil : data
    }

    // The transactions gateway rejects a whole events batch if any timestamp falls outside the
    // year range [2000, 2100], so an out-of-range value (e.g. from a device with a misconfigured
    // clock) is stripped rather than sent — the gateway then defaults to receive-time. Bounds
    // mirror web's `Date.UTC(2000, 0, 1)` / `Date.UTC(2101, 0, 1)`.
    private static let minAcceptedTimestampMs: Int64 = 946_684_800_000 // 2000-01-01T00:00:00Z
    private static let maxAcceptedTimestampMs: Int64 = 4_133_980_800_000 // 2101-01-01T00:00:00Z (exclusive)

    // Returns nil (so the timestamp is dropped from the wire) when the capture time is
    // missing/unparseable or outside the accepted year range. The gateway then defaults to
    // receive-time rather than us sending a value it would reject (mirrors web + Android).
    private static func epochMilliseconds(from eventTime: String) -> Int64? {
        guard let date = EventDateFormatter.dateFormatter.date(from: eventTime) else {
            return nil
        }
        let ms = Int64(date.timeIntervalSince1970 * 1000)
        return (minAcceptedTimestampMs..<maxAcceptedTimestampMs).contains(ms) ? ms : nil
    }
}
