import Foundation
struct EventModel: Equatable {
    var eventType: String
    var parentGuid: String
    var pageInstanceGuid: String?
    var metadata: [[String: String]]?
    var attributes: [[String: String]]?

    struct CountKey: Hashable {
        let eventType: String
        let parentGuid: String
        let pageInstanceGuid: String?
    }

    func countKey(matchPageInstance: Bool = true) -> CountKey {
        CountKey(eventType: eventType, parentGuid: parentGuid,
                 pageInstanceGuid: matchPageInstance ? pageInstanceGuid : nil)
    }

    static func == (l: EventModel, r: EventModel) -> Bool {
        return l.eventType == r.eventType && l.parentGuid == r.parentGuid
    }
}
