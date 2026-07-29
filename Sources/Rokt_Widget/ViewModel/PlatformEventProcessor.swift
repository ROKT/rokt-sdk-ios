import Foundation
internal import RoktUXHelper

class PlatformEventProcessor {
    static let pageSignalLoad = "pageSignalLoadStart"
    private static let errorCodeKey = "code"
    private static let errorStackTraceKey = "stackTrace"

    var processedEvents = ThreadSafeSet<ProcessedEvent>()
    private let stateBagManager: StateBagManaging?

    init(stateBagManager: StateBagManaging? = StateBagManager()) {
        self.stateBagManager = stateBagManager
    }

    func insertProcessedEvent(_ req: EventRequest) -> Bool {
        let pendingEvent = ProcessedEvent(sessionId: req.sessionId,
                                          parentGuid: req.parentGuid,
                                          eventType: req.eventType,
                                          pageInstanceGuid: req.pageInstanceGuid,
                                          attributes: req.attributes)
        return processedEvents.insert(pendingEvent).inserted
    }

    func process(_ eventPayload: [String: Any],
                 executeId: String,
                 cacheProperties: LayoutPageCacheProperties?) {
        do {
            let data = try JSONSerialization.data(withJSONObject: eventPayload, options: [])

            guard let jsonString = String(data: data, encoding: .utf8), !jsonString.isEmpty else {
                RoktLogger.shared.error("Invalid UTF-8 or empty data in event payload")
                return
            }

            guard let validatedData = jsonString.data(using: .utf8) else {
                RoktLogger.shared.error("Failed to re-encode validated UTF-8 string")
                return
            }

            let eventRequests = (try JSONDecoder().decode(RoktUXEventsPayload.self, from: validatedData)).events

            processTimingRequests(eventRequests: eventRequests, selectionId: executeId)

            sendDiagnostics(eventRequests: eventRequests)

            processInstantPurchase(eventRequests: eventRequests, executeId: executeId)
            sendAndCacheEvents(eventRequests: eventRequests, cacheProperties: cacheProperties)
        } catch {
            RoktLogger.shared.error("Failed to process platform events", error: error)
            RoktLogger.shared.debug("Event payload that failed: \(eventPayload)")
        }
    }

    private func processInstantPurchase(eventRequests: [RoktEventRequest], executeId: String) {
        eventRequests.filter {
            $0.eventType == .SignalCartItemInstantPurchaseInitiated
        }.forEach { _ in
            stateBagManager?.initiateInstantPurchase(id: executeId)
        }
        eventRequests.filter {
            $0.eventType == .SignalCartItemInstantPurchase || $0.eventType == .SignalCartItemInstantPurchaseFailure
        }.forEach { _ in
            stateBagManager?.finishInstantPurchase(id: executeId)
        }
        eventRequests.filter {
            $0.eventType == .SignalInstantPurchaseDismissal
        }.forEach { _ in
            stateBagManager?.getState(id: executeId)?
                .onRoktEvent?(RoktEvent.InstantPurchaseDismissal(identifier: executeId))
        }
    }

    private func processTimingRequests(eventRequests: [RoktEventRequest], selectionId: String) {
        // Filter for SignalImpression events with pageSignalLoad metadata (placementInteractive)
        // These events come from RoktUXHelper and contain pluginId and pluginName in metadata
        eventRequests.filter {
            $0.eventType == .SignalImpression && $0.metadata.first { $0.name == Self.pageSignalLoad } != nil
        }.forEach { event in
            guard let pluginId = event.metadata.first(where: { $0.name == timingsPluginIdKey })?.value else {
                return
            }

            let pluginName = event.metadata.first(where: { $0.name == timingsPluginNameKey })?.value
            let eventTime = event.metadata
                .first { $0.name == timingsEventTimeKey }
                .map(\.value)
                .flatMap(EventDateFormatter.dateFormatter.date(from:))

            // Set placement interactive time and plugin attributes
            Rokt.shared.roktImplementation.processedTimingsRequests?.setPlacementInteractiveTime(
                selectionId: selectionId,
                eventTime
            )
            Rokt.shared.roktImplementation.processedTimingsRequests?.setPluginAttributes(
                selectionId: selectionId,
                pluginId: pluginId,
                pluginName: pluginName
            )

            // Send the timing request
            Rokt.shared.roktImplementation.processedTimingsRequests?.processTimingsRequest(
                selectionId: selectionId
            )
        }
    }

    private func sendDiagnostics(eventRequests: [RoktEventRequest]) {
        eventRequests.filter {
            $0.eventType == .SignalSdkDiagnostic
        }.forEach {
            RoktAPIHelper.sendDiagnostics(message: $0.eventData.first { $0.name == Self.errorCodeKey}?.value ?? "",
                                          callStack: $0.eventData.first { $0.name == Self.errorStackTraceKey}?.value ?? "",
                                          sessionId: $0.sessionId)
        }
    }

    private func sendAndCacheEvents(eventRequests: [RoktEventRequest],
                                    cacheProperties: LayoutPageCacheProperties?) {
        let nonDiagnosticEvents = eventRequests.filter { $0.eventType != .SignalSdkDiagnostic }

        let sendEvents = { (events: [RoktEventRequest]) in
            RealTimeEventManager.shared.markEventsAsTriggered(triggeredEvents: events)
            Rokt.shared.roktImplementation.dispatchTxnEvents(
                events.compactMap { TxnEventMapper.event(from: $0) }
            )
        }

        guard !nonDiagnosticEvents.isEmpty else { return }

        // In-memory dedup runs unconditionally, regardless of cache state.
        // Previously this only ran when the cache was enabled, so with the cache off every event —
        // including exact duplicates — was re-sent. Always-resend events (user interactions) are exempt
        // so repeated user actions are never dropped.
        let sentEventHashes = Rokt.shared.roktImplementation.sentEventHashes
        let newEvents = nonDiagnosticEvents.filter { event in
            guard Self.shouldDeduplicate(event) else { return true }
            return sentEventHashes.insert(ProcessedEvent(event).getHashString()).inserted
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

    // Events exempt from dedup are always re-sent. User interactions are exempt: on iOS they surface as
    // both `.SignalUserInteraction` and `.SignalActivation` (both map to the `user_interaction` wire type
    // in TxnEventMapper), so both are exempt — a user tapping the same control twice must reach the server
    // both times.
    private static func shouldDeduplicate(_ event: RoktEventRequest) -> Bool {
        switch event.eventType {
        case .SignalUserInteraction, .SignalActivation:
            return false
        default:
            return true
        }
    }
}
