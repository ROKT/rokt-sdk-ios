import XCTest

/// Reads the sample app's automation transcript through the accessibility tree.
///
/// The app writes the same JSON lines to stdout, but a UI test runs out of process and cannot
/// see the app's stdout — so the on-screen transcript view is the channel.
struct AutomationTranscriptReader {

    static let textViewIdentifier = "rokt-automation-transcript"

    let app: XCUIApplication

    private var element: XCUIElement {
        app.textViews[Self.textViewIdentifier]
    }

    /// Every recorded line, oldest first.
    var lines: [[String: Any]] {
        let raw = (element.value as? String) ?? ""
        return raw
            .split(separator: "\n")
            .compactMap { line in
                guard let data = line.data(using: .utf8) else { return nil }
                return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            }
    }

    func events(named name: String) -> [[String: Any]] {
        lines.filter { $0["event"] as? String == name }
    }

    /// The last height the SDK published for `placement`, or `nil` if it never published one.
    func lastPublishedHeight(forPlacement placement: String) -> Double? {
        events(named: "EmbeddedSizeChanged")
            .last { $0["placement"] as? String == placement }
            .flatMap { $0["height"] as? Double }
    }

    /// The last height the host's own view settled at for `placement`.
    func lastHostHeight(forPlacement placement: String) -> Double? {
        events(named: "HostHeights").last.flatMap { $0[placement] as? Double }
    }

    @discardableResult
    func waitForEvent(named name: String, timeout: TimeInterval = 30) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !events(named: name).isEmpty { return true }
            _ = element.waitForExistence(timeout: 0.5)
        }
        return false
    }

    /// Renders the whole transcript for an assertion message.
    var debugDescription: String {
        ((element.value as? String) ?? "<no transcript>")
    }
}
