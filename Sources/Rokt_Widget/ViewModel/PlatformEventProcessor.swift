import Foundation
internal import RoktUXHelper

class PlatformEventProcessor {

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
                RoktAPIHelper.sendEvents(events: (eventPayload["events"] as? [[String: Any]]) ?? [])
                return
            }

            guard let validatedData = jsonString.data(using: .utf8) else {
                RoktLogger.shared.error("Failed to re-encode validated UTF-8 string")
                RoktAPIHelper.sendEvents(events: (eventPayload["events"] as? [[String: Any]]) ?? [])
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
            RoktAPIHelper.sendEvents(events: (eventPayload["events"] as? [[String: Any]]) ?? [])
        }
    }

    func getEventParams(_ event: RoktEventRequest) -> [String: Any] {
        var params: [String: Any] = event.getParams
        // If eventData is present, move it to attributes
        if let eventData = params[BE_EVENT_DATA_KEY] {
            params[BE_ATTRIBUTES_KEY] = eventData
        }
        params.removeValue(forKey: BE_EVENT_DATA_KEY)
        return params
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
    }

    private func processTimingRequests(eventRequests: [RoktEventRequest], selectionId: String) {
        // Filter for SignalImpression events with pageSignalLoad metadata (placementInteractive)
        // These events come from RoktUXHelper and contain pluginId and pluginName in metadata
        eventRequests.filter {
            $0.eventType == .SignalImpression && $0.metadata.first { $0.name == BE_PAGE_SIGNAL_LOAD } != nil
        }.forEach { event in
            guard let pluginId = event.metadata.first(where: { $0.name == BE_TIMINGS_PLUGIN_ID_KEY })?.value else {
                return
            }

            let pluginName = event.metadata.first(where: { $0.name == BE_TIMINGS_PLUGIN_NAME_KEY })?.value
            let eventTime = event.metadata
                .first { $0.name == BE_TIMINGS_EVENT_TIME_KEY }
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
            RoktAPIHelper.sendDiagnostics(message: $0.eventData.first { $0.name == kErrorCode}?.value ?? "",
                                          callStack: $0.eventData.first { $0.name == kErrorStackTrace}?.value ?? "",
                                          sessionId: $0.sessionId)
        }
    }

    private func sendAndCacheEvents(eventRequests: [RoktEventRequest],
                                    cacheProperties: LayoutPageCacheProperties?) {
        let nonDiagnosticEvents = eventRequests.filter { $0.eventType != .SignalSdkDiagnostic }

        let sendEvents = { [weak self] (events: [RoktEventRequest]) in
            guard let self else { return }
            RealTimeEventManager.shared.markEventsAsTriggered(triggeredEvents: events)
            RoktAPIHelper.sendEvents(events: events.map { self.getEventParams($0)})
        }

        guard !nonDiagnosticEvents.isEmpty,
              #available(iOS 13.0, *),
              Rokt.shared.roktImplementation.initFeatureFlags.isEnabled(.cacheEnabled),
              Rokt.shared.roktImplementation.roktConfig.cacheConfig.isCacheEnabled(),
              let cacheProperties
        else {
            sendEvents(nonDiagnosticEvents)
            return
        }
        // If cache enabled, filters out already sent cached non-diagnostic events
        let newEvents = nonDiagnosticEvents.filter {
            let processedEvent = ProcessedEvent($0)
            return Rokt.shared.roktImplementation.sentEventHashes.insert(processedEvent.getHashString()).inserted
        }
        guard !newEvents.isEmpty else {
            return
        }
        // Sends new events and updates cache
        sendEvents(newEvents)
        ExperienceCacheManager.cacheExperiencesViewStateSentEventHashes(viewName: cacheProperties.viewName,
                                                                        attributes: cacheProperties.attributes,
                                                                        sentEventHashes: Rokt.shared.roktImplementation
                                                                        .sentEventHashes.allElements)
    }
}
