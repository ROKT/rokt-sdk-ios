import Foundation
internal import RoktUXHelper

internal let maximumRealTimeEventsToStore: Int = 50

protocol RealTimeEventStore {
    func addUntriggeredEvents(_ events: [UntriggeredRealTimeEvent])
    func getTriggeredEvents() -> [TriggeredRealTimeEvent]
    func markAsTriggered(_ triggeredEvents: [RoktEventRequest])
    func clear()
}

class RealtimeEventStoreMemory: RealTimeEventStore {
    private var untriggeredEvents: [UntriggeredRealTimeEvent] = []
    private var triggeredEvents: [TriggeredRealTimeEvent] = []

    func addUntriggeredEvents(_ events: [UntriggeredRealTimeEvent]) {
        appendDeduped(events, to: &untriggeredEvents)
        if untriggeredEvents.count > maximumRealTimeEventsToStore {
            untriggeredEvents = Array(untriggeredEvents.suffix(maximumRealTimeEventsToStore))
        }
    }

    func getTriggeredEvents() -> [TriggeredRealTimeEvent] {
        return triggeredEvents
    }

    func markAsTriggered(_ triggeredEvents: [RoktEventRequest]) {
        let currentTriggeredEvents = self.triggeredEvents
        let updatedTriggeredEvents = updateTriggeredEvents(
            currentTriggeredEvents: currentTriggeredEvents,
            triggeredEventsToMarkAsTriggered: triggeredEvents,
            untriggeredEvents: untriggeredEvents
        )

        if currentTriggeredEvents == updatedTriggeredEvents { return }
        self.triggeredEvents = updatedTriggeredEvents
    }

    func clear() {
        untriggeredEvents.removeAll()
        triggeredEvents.removeAll()
    }
}

class RealTimeEventStoreFile: RealTimeEventStore {
    private let untriggeredEventsFilePath: URL?
    private let triggeredEventsFilePath: URL?

    private var debounceTimer: Timer?
    private var accumulatedEventsToMark: [RoktEventRequest] = []
    private let debounceInterval: TimeInterval = 0.5
    private let eventProcessingQueue = DispatchQueue(label: "com.rokt.RealTimeEventManager.eventProcessingQueue")

    // File paths are injectable so tests can isolate each case to its own temporary files.
    // Production uses the document-directory defaults.
    init(
        triggeredEventsFilePath: URL? = RealTimeEventStoreFile.defaultFileURL(named: "triggered_events.json"),
        untriggeredEventsFilePath: URL? = RealTimeEventStoreFile.defaultFileURL(named: "untriggered_events.json")
    ) {
        self.triggeredEventsFilePath = triggeredEventsFilePath
        self.untriggeredEventsFilePath = untriggeredEventsFilePath
    }

    private static func defaultFileURL(named name: String) -> URL? {
        guard let directory = FileManager
            .default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first else {
            RoktLogger.shared.error("Document directory unavailable - RealTimeEventStore will not persist events")
            return nil
        }
        return directory.appendingPathComponent(name)
    }

    func addUntriggeredEvents(_ events: [UntriggeredRealTimeEvent]) {
        guard let untriggeredEventsFilePath else { return }
        // Serialize on the same queue as markAsTriggered's processing: this is a
        // read-modify-write, so concurrent captures (or a capture racing a trigger-mark)
        // would otherwise lose updates when the second save overwrites the first.
        eventProcessingQueue.sync {
            var all = getUntriggeredEvents()
            appendDeduped(events, to: &all)
            // Bound the untriggered file the way triggered events are capped: a long-lived
            // session whose responses echo distinct event_data must not grow without limit.
            if all.count > maximumRealTimeEventsToStore {
                all = Array(all.suffix(maximumRealTimeEventsToStore))
            }
            save(all, to: untriggeredEventsFilePath)
        }
    }

    func getTriggeredEvents() -> [TriggeredRealTimeEvent] {
        guard let triggeredEventsFilePath else { return [] }
        return load(from: triggeredEventsFilePath)
    }

    func markAsTriggered(_ triggeredEvents: [RoktEventRequest]) {
        guard !triggeredEvents.isEmpty else { return }

        eventProcessingQueue.async { [weak self] in
            guard let self = self else { return }

            self.accumulatedEventsToMark.append(contentsOf: triggeredEvents)

            DispatchQueue.main.async {
                self.debounceTimer?.invalidate()
                self.debounceTimer = Timer.scheduledTimer(
                    timeInterval: self.debounceInterval,
                    target: self,
                    selector: #selector(self.handleDebounceTimerFire),
                    userInfo: nil,
                    repeats: false
                )
            }
        }
    }

    @objc private func handleDebounceTimerFire() {
        eventProcessingQueue.async { [weak self] in
            self?.processAccumulatedEvents()
        }
    }

    private func processAccumulatedEvents() {
        guard !accumulatedEventsToMark.isEmpty else {
            return
        }

        guard let triggeredEventsFilePath else {
            accumulatedEventsToMark.removeAll()
            return
        }

        let triggeredEvents = accumulatedEventsToMark
        accumulatedEventsToMark.removeAll()

        let untriggeredEvents = getUntriggeredEvents()
        let currentTriggeredEvents = getTriggeredEvents()

        let updatedTriggeredEvents = updateTriggeredEvents(
            currentTriggeredEvents: currentTriggeredEvents,
            triggeredEventsToMarkAsTriggered: triggeredEvents,
            untriggeredEvents: untriggeredEvents
        )

        if currentTriggeredEvents == updatedTriggeredEvents { return }
        save(updatedTriggeredEvents, to: triggeredEventsFilePath)
    }

    func clear() {
        if let untriggeredEventsFilePath {
            try? FileManager.default.removeItem(at: untriggeredEventsFilePath)
        }
        if let triggeredEventsFilePath {
            try? FileManager.default.removeItem(at: triggeredEventsFilePath)
        }
    }

    #if DEBUG
    // Test hook: cancels any pending debounce and drops accumulated marks so a scheduled
    // write cannot fire after a test finishes. Not referenced in production code.
    func cancelPendingWorkForTesting() {
        let invalidate = {
            self.debounceTimer?.invalidate()
            self.debounceTimer = nil
        }
        if Thread.isMainThread {
            invalidate()
        } else {
            DispatchQueue.main.sync(execute: invalidate)
        }
        eventProcessingQueue.sync { self.accumulatedEventsToMark.removeAll() }
    }
    #endif

    private func getUntriggeredEvents() -> [UntriggeredRealTimeEvent] {
        guard let untriggeredEventsFilePath else { return [] }
        return load(from: untriggeredEventsFilePath)
    }

    private func save<T: Codable>(_ value: T, to url: URL) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(value)
            // Encrypt at rest with iOS Data Protection. Use `.completeFileProtectionUntilFirstUserAuthentication`
            // (not `.completeFileProtection`): events are persisted during normal app runtime, including while
            // backgrounded and the device is locked. A stricter class would make those writes fail and drop
            // events. This mirrors the protection level used by TxnPendingEventStore.
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            RoktLogger.shared.error("Failed to save real-time events", error: error)
        }
    }

    private func load<T: Codable>(from url: URL) -> [T] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([T].self, from: data)) ?? []
    }
}

// MARK: - Helper functions

private func doEventsMatch(event: UntriggeredRealTimeEvent, trigger: RoktEventRequest) -> Bool {
    let parentGuidsMatch = (event.triggerGuid == trigger.parentGuid)
    let eventTypesMatch = (event.triggerEvent == trigger.eventType.rawValue)
    return parentGuidsMatch && eventTypesMatch
}

private func updateTriggeredEvents(
    currentTriggeredEvents: [TriggeredRealTimeEvent],
    triggeredEventsToMarkAsTriggered: [RoktEventRequest],
    untriggeredEvents: [UntriggeredRealTimeEvent]
) -> [TriggeredRealTimeEvent] {
    var updatedTriggeredEvents: [TriggeredRealTimeEvent] = currentTriggeredEvents

    for triggeredEvent in triggeredEventsToMarkAsTriggered {
        for storedEvent in untriggeredEvents where doEventsMatch(event: storedEvent, trigger: triggeredEvent) {
            let newTriggeredEvent = TriggeredRealTimeEvent(
                parentGuid: storedEvent.triggerGuid!,
                eventType: storedEvent.eventType!,
                eventTime: triggeredEvent.eventTime,
                payload: storedEvent.payload!
            )
            updatedTriggeredEvents.append(newTriggeredEvent)
        }
    }
    let trimmedTriggeredEvents = trimTriggeredEvents(updatedTriggeredEvents)
    return trimmedTriggeredEvents
}

private func trimTriggeredEvents(_ triggeredEvents: [TriggeredRealTimeEvent]) -> [TriggeredRealTimeEvent] {
    let sortedEvents = triggeredEvents.sorted { $0.eventTime > $1.eventTime }
    return Array(sortedEvents.prefix(maximumRealTimeEventsToStore))
}

// Appends only events not already present, preserving order. The backend can echo the same
// event_data across responses; de-duping keeps the untriggered store bounded and stops a single
// trigger from matching duplicate rows and multiplying what gets forwarded.
private func appendDeduped(_ events: [UntriggeredRealTimeEvent], to all: inout [UntriggeredRealTimeEvent]) {
    var seen = Set(all)
    for event in events where seen.insert(event).inserted {
        all.append(event)
    }
}
