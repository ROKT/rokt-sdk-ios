import Foundation

struct SDKOption: Decodable {

    enum Option: String, Decodable {
        case useDiagnosticEvents
    }

    let key: Option
    let value: Bool

    init?(element: Dictionary<String, Bool>.Element) {
        guard let key = Option(rawValue: element.key) else { return nil }
        self.key = key
        self.value = element.value
    }

    init(key: Option, value: Bool) {
        self.key = key
        self.value = value
    }
}

extension SDKOption {

    static var useDiagnosticEvents: SDKOption {
        .init(key: .useDiagnosticEvents, value: true)
    }
}

extension Sequence where Element == SDKOption {

    var useDiagnosticEvents: Bool {
        first(where: { $0.key == .useDiagnosticEvents })?.value == true
    }
}
