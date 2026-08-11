import Foundation
internal import RoktUXHelper

class PlatformEventProcessor {
    static let pageSignalLoad = "page_signal_load_start"
    private static let errorCodeKey = "code"
    private static let errorStackTraceKey = "stackTrace"

    // Timing metadata keys as the renderer now emits them in the v2 events `data` object
    // (snake_case). Distinct from the Timings-API request keys (`timingsPluginIdKey` etc.),
    // which remain camelCase — that is a separate contract.
    private static let dataPluginIdKey = "plugin_id"
    private static let dataPluginNameKey = "plugin_name"
    private static let dataEventTimeKey = "event_time"

    // Routing keys the renderer flattens into `data`; kept out of the dedup attribute set.
    private static let parentIdKey = "parent_id"
    private static let tokenKey = "token"
    private static let pageInstanceGuidKey = "page_instance_guid"
    private static let interactionTypeKey = "interaction_type"

    // Wire event-type strings emitted by RoktUXHelper's v2 sessions/events payload.
    private enum Wire {
        static let impression = "impression"
        static let sdkDiagnostic = "sdk_diagnostic"
        static let userInteraction = "user_interaction"
        static let instantPurchaseInitiated = "cart_item_instant_purchase_initiated"
        static let instantPurchase = "cart_item_instant_purchase"
        static let instantPurchaseFailure = "cart_item_instant_purchase_failure"
        static let instantPurchaseDismissal = "instant_purchase_dismissal"
    }

    var processedEvents = ThreadSafeSet<ProcessedEvent>()
    private let stateBagManager: StateBagManaging?

    init(stateBagManager: StateBagManaging? = StateBagManager()) {
        self.stateBagManager = stateBagManager
    }

    func insertProcessedEvent(_ req: EventRequest) -> Bool {
        let pendingEvent = ProcessedEvent(
            sessionId: req.sessionId,
            parentGuid: req.parentGuid,
            eventType: req.eventType.rawValue,
            pageInstanceGuid: req.pageInstanceGuid,
            attributes: Self.dictionary(from: req.attributes)
        )
        return processedEvents.insert(pendingEvent).inserted
    }

    /// Decodes the v2 `sessions/events` payload emitted by RoktUXHelper's `onRoktPlatformEvent`
    /// and drives the SDK's timing, diagnostics, instant-purchase, dedup and dispatch side-effects.
    func process(_ eventPayload: [String: Any],
                 executeId: String,
                 cacheProperties: LayoutPageCacheProperties?) {
        do {
            let data = try JSONSerialization.data(withJSONObject: eventPayload, options: [])
            let events = try JSONDecoder().decode(PlatformEventBatch.self, from: data).events

            processTimingRequests(events: events, selectionId: executeId)
            sendDiagnostics(events: events)
            processInstantPurchase(events: events, executeId: executeId)
            sendAndCacheEvents(events: events, cacheProperties: cacheProperties)
        } catch {
            RoktLogger.shared.error("Failed to process platform events", error: error)
            RoktLogger.shared.debug("Event payload that failed: \(eventPayload)")
        }
    }

    private func processInstantPurchase(events: [PlatformEvent], executeId: String) {
        events.filter { $0.eventType == Wire.instantPurchaseInitiated }.forEach { _ in
            stateBagManager?.initiateInstantPurchase(id: executeId)
        }
        events.filter {
            $0.eventType == Wire.instantPurchase || $0.eventType == Wire.instantPurchaseFailure
        }.forEach { _ in
            stateBagManager?.finishInstantPurchase(id: executeId)
        }
        events.filter { $0.eventType == Wire.instantPurchaseDismissal }.forEach { _ in
            stateBagManager?.getState(id: executeId)?
                .onRoktEvent?(RoktEvent.InstantPurchaseDismissal(identifier: executeId))
        }
    }

    private func processTimingRequests(events: [PlatformEvent], selectionId: String) {
        // SignalImpression events carrying the placement-interactive marker; they hold the
        // pluginId/pluginName/eventTime in the flattened `data` map.
        events.filter {
            $0.eventType == Wire.impression && $0.data[Self.pageSignalLoad] != nil
        }.forEach { event in
            guard let pluginId = event.data[Self.dataPluginIdKey] else {
                return
            }

            let pluginName = event.data[Self.dataPluginNameKey]
            let eventTime = event.data[Self.dataEventTimeKey]
                .flatMap(EventDateFormatter.dateFormatter.date(from:))

            Rokt.shared.roktImplementation.processedTimingsRequests?.setPlacementInteractiveTime(
                selectionId: selectionId,
                eventTime
            )
            Rokt.shared.roktImplementation.processedTimingsRequests?.setPluginAttributes(
                selectionId: selectionId,
                pluginId: pluginId,
                pluginName: pluginName
            )
            Rokt.shared.roktImplementation.processedTimingsRequests?.processTimingsRequest(
                selectionId: selectionId
            )
        }
    }

    private func sendDiagnostics(events: [PlatformEvent]) {
        events.filter { $0.eventType == Wire.sdkDiagnostic }.forEach {
            RoktAPIHelper.sendDiagnostics(message: $0.data[Self.errorCodeKey] ?? "",
                                          callStack: $0.data[Self.errorStackTraceKey] ?? "",
                                          sessionId: $0.sessionId)
        }
    }

    private func sendAndCacheEvents(events: [PlatformEvent],
                                    cacheProperties: LayoutPageCacheProperties?) {
        let nonDiagnosticEvents = events.filter { $0.eventType != Wire.sdkDiagnostic }

        let sendEvents = { (events: [PlatformEvent]) in
            RealTimeEventManager.shared.markEventsAsTriggered(
                triggeredEvents: events.map { Self.realTimeTrigger(from: $0) }
            )
            Rokt.shared.roktImplementation.dispatchTxnEvents(
                events.map { Self.txnEvent(from: $0) }
            )
        }

        guard !nonDiagnosticEvents.isEmpty else { return }

        // In-memory dedup runs unconditionally, regardless of cache state. Always-resend events
        // (user interactions) are exempt so repeated user actions are never dropped.
        let sentEventHashes = Rokt.shared.roktImplementation.sentEventHashes
        let newEvents = nonDiagnosticEvents.filter { event in
            guard Self.shouldDeduplicate(event) else { return true }
            return sentEventHashes.insert(Self.processedEvent(from: event).getHashString()).inserted
        }
        guard !newEvents.isEmpty else { return }

        sendEvents(newEvents)

        // Cache-persistence stays gated: only persist the sent-event hashes when the cache is
        // enabled + configured and we have cache properties for the current view.
        guard Rokt.shared.roktImplementation.initFeatureFlags.isEnabled(.cacheEnabled),
              Rokt.shared.roktImplementation.roktConfig.cacheConfig.isCacheEnabled(),
              let cacheProperties
        else { return }

        ExperienceCacheManager.cacheExperiencesViewStateSentEventHashes(viewName: cacheProperties.viewName,
                                                                        attributes: cacheProperties
                                                                            .experienceCacheAttributes,
                                                                        sentEventHashes: Rokt.shared.roktImplementation
                                                                        .sentEventHashes.allElements)
    }

    // Events exempt from dedup are always re-sent. User interactions (both SignalUserInteraction and
    // SignalActivation collapse to the `user_interaction` wire type) are exempt so a user tapping the
    // same control twice reaches the server both times.
    private static func shouldDeduplicate(_ event: PlatformEvent) -> Bool {
        return event.eventType != Wire.userInteraction
    }

    // MARK: - Mapping

    private static func processedEvent(from event: PlatformEvent) -> ProcessedEvent {
        var attributes = event.data
        // Routing/volatile fields are keyed separately (or would defeat dedup on token rotation).
        attributes.removeValue(forKey: parentIdKey)
        attributes.removeValue(forKey: tokenKey)
        attributes.removeValue(forKey: pageInstanceGuidKey)
        return ProcessedEvent(
            sessionId: event.sessionId,
            parentGuid: event.data[parentIdKey] ?? "",
            eventType: event.eventType,
            pageInstanceGuid: event.data[pageInstanceGuidKey] ?? "",
            attributes: attributes
        )
    }

    // The renderer already produced the v2 wire shape (registry event_type + flattened data with
    // parent_id/token/page_instance_guid/capture_method), so the SDK forwards it verbatim under its
    // own channel/auth — no re-mapping needed.
    private static func txnEvent(from event: PlatformEvent) -> TxnEvent {
        TxnEvent(
            eventType: event.eventType,
            instanceId: event.instanceId,
            timestamp: event.timestamp.flatMap(acceptedTimestamp),
            data: event.data.mapValues { TxnEventDataValue.string($0) }
        )
    }

    private static func realTimeTrigger(from event: PlatformEvent) -> RealTimeTrigger {
        let eventTime = event.timestamp
            .map { EventDateFormatter.getDateString(Date(timeIntervalSince1970: Double($0)/1000)) }
            ?? EventDateFormatter.getDateString(Date())
        return RealTimeTrigger(
            parentGuid: event.data[parentIdKey] ?? "",
            // Untriggered events from the offers response are keyed by the legacy signal name
            // (e.g. `SignalResponse`), so bridge the wire event_type back for matching.
            eventTypeKey: legacySignalName(
                for: event.eventType,
                interactionType: event.data[interactionTypeKey]
            ),
            eventTime: eventTime
        )
    }

    private static func dictionary(from nameValues: [RoktEventNameValue]) -> [String: String] {
        nameValues.reduce(into: [String: String]()) { $0[$1.name] = $1.value }
    }

    // Omit implausible timestamps so event delivery can use receive-time instead.
    private static let minAcceptedTimestampMs: Int64 = 946_684_800_000
    private static let maxAcceptedTimestampMs: Int64 = 4_133_980_800_000
    private static func acceptedTimestamp(_ ms: Int64) -> Int64? {
        (minAcceptedTimestampMs..<maxAcceptedTimestampMs).contains(ms) ? ms : nil
    }

    // Wire event_type -> legacy signal name, mirroring RoktUXEventType.rawValue. Used only to match
    // the offers response's untriggered real-time-event keys, which still use the legacy names.
    static func legacySignalName(for wireEventType: String, interactionType: String? = nil) -> String {
        switch wireEventType {
        case Wire.impression: return "SignalImpression"
        case "viewed": return "SignalViewed"
        case "signal_response": return "SignalResponse"
        case "signal_gated_response": return "SignalGatedResponse"
        case "dismissal": return "SignalDismissal"
        case "signal_initialize": return "SignalInitialize"
        case "load_start": return "SignalLoadStart"
        case "load_complete": return "SignalLoadComplete"
        case Wire.userInteraction:
            return interactionType == "activation" ? "SignalActivation" : "SignalUserInteraction"
        case Wire.sdkDiagnostic: return "SignalSdkDiagnostic"
        case Wire.instantPurchase: return "SignalCartItemInstantPurchase"
        case Wire.instantPurchaseFailure: return "SignalCartItemInstantPurchaseFailure"
        case Wire.instantPurchaseInitiated: return "SignalCartItemInstantPurchaseInitiated"
        case Wire.instantPurchaseDismissal: return "SignalInstantPurchaseDismissal"
        case "capture_attributes": return "CaptureAttributes"
        default: return wireEventType
        }
    }
}

// MARK: - v2 sessions/events wire shape

/// The `onRoktPlatformEvent` payload: RoktUXHelper's v2 `sessions/events` body.
private struct PlatformEventBatch: Decodable {
    let events: [PlatformEvent]
}

private struct PlatformEvent: Decodable {
    let eventType: String
    let instanceId: String
    let sessionId: String
    let timestamp: Int64?
    let data: [String: String]

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case instanceId = "instance_id"
        case sessionId = "session_id"
        case timestamp
        case data
    }
}
