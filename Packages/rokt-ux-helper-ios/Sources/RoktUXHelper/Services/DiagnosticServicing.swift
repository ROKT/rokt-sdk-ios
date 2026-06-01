import Foundation

enum Severity: String, Codable {
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}

protocol DiagnosticServicing: AnyObject {

    var pluginInstanceGuid: String { get }
    var pluginConfigJWTToken: String { get }
    var useDiagnosticEvents: Bool { get }

    func sendEvent(
        _ eventType: RoktUXEventType,
        parentGuid: String,
        extraMetadata: [RoktEventNameValue],
        eventData: [String: String],
        objectData: [String: String]?,
        jwtToken: String
    )

    func sendDiagnostics(
        message: String,
        callStack: String,
        severity: Severity
    )

    func sendFontDiagnostics(_ fontFamily: String)
}

extension DiagnosticServicing {

    func sendDiagnostics(
        message: String,
        callStack: String,
        severity: Severity = .error
    ) {
        guard useDiagnosticEvents else { return }
        sendEvent(
            .SignalSdkDiagnostic,
            parentGuid: pluginInstanceGuid,
            extraMetadata: [],
            eventData: [
                kErrorCode: message,
                kErrorStackTrace: callStack,
                kErrorSeverity: severity.rawValue
            ],
            objectData: [:],
            jwtToken: pluginConfigJWTToken
        )
    }

    func sendFontDiagnostics(_ fontFamily: String) {
        sendDiagnostics(message: kViewErrorCode,
                        callStack: kUIFontErrorMessage + fontFamily)
    }
}
