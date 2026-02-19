import Foundation
internal import RoktUXHelper

enum StorageType {
    case memory
    case file
}

class RealTimeEventManager: ManagedSession {

    static let shared = RealTimeEventManager(storageType: .file)
    private let store: RealTimeEventStore

    private init(storageType: StorageType) {
        switch storageType {
        case .memory:
            store = RealtimeEventStoreMemory()
        case .file:
            store = RealTimeEventStoreFile()
        }
    }

    /// Add untriggered events to storage. Filters out invalid events.
    func addUntriggeredEvents(_ untriggeredEvents: [UntriggeredRealTimeEvent]) {
        let validEvents = untriggeredEvents.filter { $0.isValid() }
        store.addUntriggeredEvents(validEvents)
    }

    /// Get all events that have been flagged as triggered
    func getTriggeredEvents() -> [TriggeredRealTimeEvent] {
        return store.getTriggeredEvents()
    }

    /// Flag the events as being triggered so they can be sent to the API.
    /// This method debounces calls and aggregates events before processing.
    func markEventsAsTriggered(triggeredEvents: [RoktEventRequest]) {
        store.markAsTriggered(triggeredEvents)
    }

    /// Remove all events from store regardless of if they are triggered or untriggered.
    /// This also cancels any pending debounced event marking.
    func clearAllEvents() {
        store.clear()
    }

    func sessionInvalidated() {
        clearAllEvents()
    }
}

struct TriggeredRealTimeEvent: Codable, Equatable {
    let parentGuid: String
    let eventType: String
    let eventTime: String
    let payload: String
}
