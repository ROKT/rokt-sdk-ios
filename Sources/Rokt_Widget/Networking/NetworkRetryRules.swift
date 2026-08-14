import Foundation

/// Shared classification of URL-layer failures that may succeed if the same request is sent again.
///
/// Status-code policy deliberately stays with each caller — init, offers, events, forward payment
/// and the legacy post/download path do not agree on which HTTP codes are worth another attempt —
/// but the transport allowlist is the same question everywhere, and the hand-maintained copies had
/// already drifted apart on the offline case.
enum NetworkRetryRules {

    /// How much of the transient set a given caller is willing to come back for.
    enum TransportPolicy {
        /// Timeouts only. The legacy `performPost` / font download path, which retries in place
        /// almost immediately and treats every other transport failure as terminal.
        case timeoutOnly
        /// Transient failures, but not a device with no connectivity: an in-request retry loop
        /// should fail fast rather than spend its attempts while the radio is down.
        case transient
        /// Transient failures including offline, for work that is persisted or rescheduled and
        /// comes back seconds or minutes later rather than inline.
        case transientIncludingOffline
    }

    static func isTransientTransportFailure(_ error: Error, policy: TransportPolicy) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return false }

        switch nsError.code {
        case NSURLErrorTimedOut:
            return true
        case NSURLErrorNetworkConnectionLost,
             NSURLErrorCannotConnectToHost,
             NSURLErrorCannotFindHost,
             NSURLErrorDNSLookupFailed:
            return policy != .timeoutOnly
        case NSURLErrorNotConnectedToInternet:
            return policy == .transientIncludingOffline
        default:
            // Cancelled requests, bad URLs and TLS/ATS rejections fail the same way every time.
            return false
        }
    }
}
