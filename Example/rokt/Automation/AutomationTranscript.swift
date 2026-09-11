import UIKit
import Rokt_Widget

/// Machine-readable record of every host-facing Rokt signal in a run, so a failure that is only
/// visible in the host — a placement that renders but never collapses, say — can be asserted on
/// instead of eyeballed.
///
/// Two sinks for the same lines: stdout behind ``linePrefix``, greppable from `xcodebuild`
/// output, and an optional on-screen text view an XCUITest reads through the accessibility tree
/// without parsing build logs.
final class AutomationTranscript {

    static let shared = AutomationTranscript()

    static let linePrefix = "ROKT_TRANSCRIPT "
    static let textViewAccessibilityIdentifier = "rokt-automation-transcript"

    private let lock = NSLock()
    private let startedAt = Date()
    private var lines: [String] = []
    private weak var textView: UITextView?

    /// Mirrors subsequent lines into `textView`, and back-fills anything already recorded so a
    /// test that attaches late still sees the whole run.
    func attach(to textView: UITextView) {
        textView.accessibilityIdentifier = Self.textViewAccessibilityIdentifier
        textView.isAccessibilityElement = true
        lock.lock()
        self.textView = textView
        let backlog = lines
        lock.unlock()
        render(backlog)
    }

    func record(_ event: RoktEvent) {
        if let sizeChange = event as? RoktEvent.EmbeddedSizeChanged {
            // The signal a host sizes its container from, and the one worth asserting on: a
            // collapse is a final height of 0.
            record(
                "EmbeddedSizeChanged",
                ["placement": sizeChange.identifier, "height": sizeChange.updatedHeight]
            )
        } else {
            record(String(describing: type(of: event)), [:])
        }
    }

    /// The heights the host's own views actually settled at, recorded alongside the published
    /// height so "the SDK collapsed but the host did not" is visible rather than inferred.
    func record(observedHeights: [String: CGFloat]) {
        record("ObservedHeights", observedHeights.mapValues { $0 })
    }

    func record(_ name: String, _ fields: [String: Any]) {
        var payload: [String: Any] = fields
        payload["event"] = name
        payload["t"] = Date().timeIntervalSince(startedAt)

        let line: String
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            line = json
        } else {
            line = "{\"event\":\"\(name)\",\"error\":\"unserialisable\"}"
        }

        print(Self.linePrefix + line)

        lock.lock()
        lines.append(line)
        lock.unlock()
        render([line])
    }

    /// Every line recorded so far, newest last.
    var recordedLines: [String] {
        lock.lock()
        defer { lock.unlock() }
        return lines
    }

    private func render(_ newLines: [String]) {
        guard !newLines.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let textView = self.textView
            self.lock.unlock()
            guard let textView else { return }
            let existing = textView.text ?? ""
            textView.text = existing + newLines.joined(separator: "\n") + "\n"
            // `value` is what XCUIElement surfaces for a text view.
            textView.accessibilityValue = textView.text
        }
    }
}
