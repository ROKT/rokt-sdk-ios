import Foundation
internal import RoktUXHelper

// Maps domain events to the v2 wire shape. Reserved keys (parent_id, token, page_instance_guid)
// are written last so partner attributes cannot overwrite them.
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
        case .SignalGatedResponse: return MappedType("signal_response", ["gated": "true"])
        case .SignalDismissal: return MappedType("dismissal")
        case .SignalActivation: return MappedType("user_interaction", ["interactionType": "activation"])
        case .SignalUserInteraction: return MappedType("user_interaction")
        case .CaptureAttributes: return MappedType("capture_attributes", ["sdk_event": "captureAttributes"])
        case .SignalCartItemInstantPurchaseInitiated: return MappedType("cart_item_instant_purchase_initiated")
        case .SignalCartItemInstantPurchase: return MappedType("cart_item_instant_purchase")
        case .SignalCartItemInstantPurchaseFailure: return MappedType("cart_item_instant_purchase_failure")
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

    // Returns nil (so the timestamp is dropped from the wire) when the capture time is
    // missing/unparseable or non-positive. The gateway then defaults to receive-time
    // rather than us sending a misleading value (mirrors web + Android).
    private static func epochMilliseconds(from eventTime: String) -> Int64? {
        guard let date = EventDateFormatter.dateFormatter.date(from: eventTime) else {
            return nil
        }
        let ms = Int64(date.timeIntervalSince1970 * 1000)
        return ms > 0 ? ms : nil
    }
}
