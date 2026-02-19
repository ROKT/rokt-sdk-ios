import Foundation
struct EventModel: Equatable {
    var eventType: String
    var parentGuid: String
    var pageInstanceGuid: String?
    var metadata: [[String: String]]?
    var attributes: [[String: String]]?
    var jwtToken: String

    static func == (l: EventModel, r: EventModel) -> Bool {
        return l.eventType == r.eventType && l.parentGuid == r.parentGuid && l.jwtToken == r.jwtToken
    }

    func containNameInMetadata(name: String) -> Bool {
        return contains(metadata, key: "name", value: name)
    }

    func containValueInMetadata(value: String) -> Bool {
        return contains(metadata, key: "value", value: value)
    }

    func containNameInAttributes(name: String) -> Bool {
        return contains(attributes, key: "name", value: name)
    }

    func containValueInAttributes(value: String) -> Bool {
        return contains(attributes, key: "value", value: value)
    }

    func contains(_ nameValues: [[String: String]]?, key: String, value: String) -> Bool {
        if let nameValues = nameValues {
            for nameValue in nameValues where nameValue[key] == value {
                return true
            }
        }
        return false
    }
}
