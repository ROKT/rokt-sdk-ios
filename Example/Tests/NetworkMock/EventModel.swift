import Foundation
struct EventModel: Equatable {
    var eventType: String
    var parentGuid: String
    var pageInstanceGuid: String?
    var metadata: [[String: String]]?
    var attributes: [[String: String]]?

    static func == (l: EventModel, r: EventModel) -> Bool {
        return l.eventType == r.eventType && l.parentGuid == r.parentGuid
    }
}
