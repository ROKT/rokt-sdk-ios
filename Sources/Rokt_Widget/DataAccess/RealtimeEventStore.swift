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
        self.untriggeredEvents.append(contentsOf: events)
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

    init() {
        guard let directory = FileManager
            .default
            .urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first else {
            RoktLogger.shared.error("Document directory unavailable - RealTimeEventStore will not persist events")
            self.triggeredEventsFilePath = nil
            self.untriggeredEventsFilePath = nil
            return
        }
        self.triggeredEventsFilePath = directory.appendingPathComponent("triggered_events.json")
        self.untriggeredEventsFilePath = directory.appendingPathComponent("untriggered_events.json")
    }

    func addUntriggeredEvents(_ events: [UntriggeredRealTimeEvent]) {
        guard let untriggeredEventsFilePath else { return }
        var all = getUntriggeredEvents()
        all.append(contentsOf: events)
        save(all, to: untriggeredEventsFilePath)
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

    private func getUntriggeredEvents() -> [UntriggeredRealTimeEvent] {
        guard let untriggeredEventsFilePath else { return [] }
        return load(from: untriggeredEventsFilePath)
    }

    private func save<T: Codable>(_ value: T, to url: URL) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
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
