import Foundation
import DcuiSchema

/// This enum defines whether to open a URL using an internal browser or delegate the task to the device's external browser.
/// - `internally`: Opens the URL within the app's internal browser, typically for in-app web view use cases.
/// - `externally`: Opens the URL using the device's default external browser, like Safari or Chrome.
/// - `passthrough`: Send the event to the consumer to handle the URL.
public enum RoktUXOpenURLType: Equatable {
    case `internally`(sessionId: String?)
    case externally
    case passthrough

    init(_ linkOpenTarget: LinkOpenTarget?, sessionId: String? = nil) {
        switch linkOpenTarget {
        case .externally:
            self = .externally
        case .passthrough:
            self = .passthrough
        default:
            self = .internally(sessionId: sessionId)
        }
    }
}
