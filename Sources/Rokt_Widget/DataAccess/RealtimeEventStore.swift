import Foundation

internal let maximumRealTimeEventsToStore: Int = 50

/// A user-side event used to trigger stored real-time events. `eventTypeKey` is the legacy
/// signal name (e.g. `SignalResponse`) that matches the offers response's untriggered-event keys.
struct RealTimeTrigger: Equatable {
    let parentGuid: String
    let eventTypeKey: String
    let eventTime: String
}

protocol RealTimeEventStore {
    func addUntriggeredEvents(_ events: [UntriggeredRealTimeEvent])
    func getTriggeredEvents() -> [TriggeredRealTimeEvent]
    func markAsTriggered(_ triggeredEvents: [RealTimeTrigger])
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

    func markAsTriggered(_ triggeredEvents: [RealTimeTrigger]) {
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
    private var accumulatedEventsToMark: [RealTimeTrigger] = []
    private let debounceInterval: TimeInterval = 0.5
    private let eventProcessingQueue = DispatchQueue(label: "com.rokt.RealTimeEventManager.eventProcessingQueue")

    static let storageDirectoryName = "RoktRealTimeEvents"
    static let triggeredEventsFileName = "triggered_events.json"
    static let untriggeredEventsFileName = "untriggered_events.json"

    // File paths are injectable so tests can isolate each case to its own temporary files.
    // Production uses the storage-directory defaults.
    init(
        triggeredEventsFilePath: URL? = RealTimeEventStoreFile
            .defaultFileURL(named: RealTimeEventStoreFile.triggeredEventsFileName),
        untriggeredEventsFilePath: URL? = RealTimeEventStoreFile
            .defaultFileURL(named: RealTimeEventStoreFile.untriggeredEventsFileName)
    ) {
        self.triggeredEventsFilePath = triggeredEventsFilePath
        self.untriggeredEventsFilePath = untriggeredEventsFilePath
    }

    private static func defaultFileURL(named name: String) -> URL? {
        guard let directory = ensureStorageDirectory() else {
            RoktLogger.shared.error("Storage directory unavailable - RealTimeEventStore will not persist events")
            return nil
        }

        return directory.appendingPathComponent(name)
    }

    /// Directory holding the persisted events. Application Support is durable (unlike Caches, which
    /// the system can purge) while staying out of the host app's documents, where these files were
    /// part of the user's backup and visible to them in apps that enable file sharing. This matches
    /// where the font cache lives.
    static func storageDirectoryUrl(fileManager: FileManager = .default) -> URL? {
        guard let supportUrl = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return supportUrl.appendingPathComponent(storageDirectoryName, isDirectory: true)
    }

    static func ensureStorageDirectory(fileManager: FileManager = .default) -> URL? {
        guard let directoryURL = storageDirectoryUrl(fileManager: fileManager) else { return nil }

        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.createDirectory(
                    at: directoryURL,
                    withIntermediateDirectories: true,
                    attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
                )
            } catch {
                return nil
            }
        }

        // Persisted events are regenerable from the next placement; they must not inflate backups.
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableURL = directoryURL
        try? mutableURL.setResourceValues(resourceValues)

        return directoryURL
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

    func markAsTriggered(_ triggeredEvents: [RealTimeTrigger]) {
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
            try createContainingDirectoryIfNeeded(of: url)
            // Encrypt at rest with iOS Data Protection. Use `.completeFileProtectionUntilFirstUserAuthentication`
            // (not `.completeFileProtection`): events are persisted during normal app runtime, including while
            // backgrounded and the device is locked. A stricter class would make those writes fail and drop
            // events. This mirrors the protection level used by TxnPendingEventStore.
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            RoktLogger.shared.error("Failed to save real-time events", error: error)
        }
    }

    // The storage directory is created up front, but saving is best-effort: were the directory to
    // go missing afterwards - removed by the host app, or never there for an injected path - every
    // save would fail for the rest of the process with nothing but a log line to show for it.
    private func createContainingDirectoryIfNeeded(of url: URL) throws {
        let directory = url.deletingLastPathComponent()
        guard !FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func load<T: Codable>(from url: URL) -> [T] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([T].self, from: data)) ?? []
    }
}

// MARK: - Helper functions

private func doEventsMatch(event: UntriggeredRealTimeEvent, trigger: RealTimeTrigger) -> Bool {
    let parentGuidsMatch = (event.triggerGuid == trigger.parentGuid)
    let eventTypesMatch = (event.triggerEvent == trigger.eventTypeKey)
    return parentGuidsMatch && eventTypesMatch
}

private func updateTriggeredEvents(
    currentTriggeredEvents: [TriggeredRealTimeEvent],
    triggeredEventsToMarkAsTriggered: [RealTimeTrigger],
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
