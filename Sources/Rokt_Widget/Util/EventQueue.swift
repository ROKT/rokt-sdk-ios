import Foundation
internal import RoktUXHelper

private let eventDelay: Double = 0.25
private let eventQueueLabel = "EventsAccessQueue"

class EventQueue: NSObject {
    private static weak var timer: Timer?
    static var events = [EventRequest]()
    static var callback: (([EventRequest]) -> Void)?

    static func call(event: EventRequest, callback: @escaping (([EventRequest]) -> Void)) {
        DispatchQueue(label: eventQueueLabel).sync {
            EventQueue.events.append(event)
        }
        timer?.invalidate()
        let nextTimer = Timer.scheduledTimer(timeInterval: eventDelay, target: self,
                                             selector: #selector(EventQueue.fireNow), userInfo: nil, repeats: false)
        timer = nextTimer
        self.callback = callback
    }

    @objc static func fireNow() {
        DispatchQueue(label: eventQueueLabel).sync {
            guard !EventQueue.events.isEmpty else { return }
            EventQueue.callback?(EventQueue.events)
            EventQueue.events = [EventRequest]()
        }
    }

    /// Drains the buffer immediately, cancelling the pending debounce timer. A no-op when the
    /// buffer is empty. Used to flush queued events when the app backgrounds so they are not
    /// lost inside the debounce window (analog of web's pagehide/visibilitychange flush).
    static func flush() {
        timer?.invalidate()
        timer = nil
        fireNow()
    }
}
