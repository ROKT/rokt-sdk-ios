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
            EventQueue.callback?(EventQueue.events)
            EventQueue.events = [EventRequest]()
        }
    }
}
