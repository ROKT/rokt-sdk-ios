import Foundation
struct MockTimingsRequest: Equatable {
    var eventTime: String
    var pageId: String?
    var pageInstanceGuid: String?
    var pluginId: String?
    var pluginName: String?
    var timings: [[String: String]]

    static func == (l: MockTimingsRequest, r: MockTimingsRequest) -> Bool {
        return (l.eventTime == r.eventTime
                && l.pageId == r.pageId
                && l.pageInstanceGuid == r.pageInstanceGuid
                && l.pluginId == r.pluginId
                && l.pluginName == r.pluginName)
    }

    func getValueInTimings(name: String) -> String? {
        self.timings.first(where: { $0["name"] == name })?["value"]
    }

    func containNameValueInTimings(name: String, value: String) -> Bool {
        return containsNameValuePair(self.timings, name: name, value: value)
    }

    func containsNameValuePair(_ nameValues: [[String: String]]?, name: String, value: String) -> Bool {
        if let nameValues = nameValues {
            for nameValue in nameValues {
                if nameValue["name"] == name,
                   nameValue["value"] == value {
                    return true
                }
            }
        }
        return false
    }
}
