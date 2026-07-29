import Foundation
import UIKit

/// Flushes buffered events when the app moves to the background.
///
/// Events queued through `EventQueue` sit in a short debounce window before they are sent. If the
/// app backgrounds inside that window the buffered events would otherwise be lost. Observing
/// `didEnterBackgroundNotification` and flushing on it is the iOS analog of the web SDK's
/// `pagehide` / `visibilitychange == hidden` flush.
final class EventFlushLifecycleObserver {
    private let flush: () -> Void

    init(
        notificationCenter: NotificationCenter = .default,
        flush: @escaping () -> Void = { EventQueue.flush() }
    ) {
        self.flush = flush
        notificationCenter.addObserver(
            self,
            selector: #selector(handleEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    @objc private func handleEnterBackground() {
        flush()
    }
}
