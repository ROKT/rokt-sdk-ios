import Foundation

/// Client-side retry hints for built-in card forwarding (`/v1/cart/purchase`).
enum CardForwardingRetryRules {
    /// HTTP 200 with `PurchaseResponse.success == false` — conservative substring hints for card forwarding retry.
    static func isCardForwardingErrorRetryable(failureReason: String?) -> Bool {
        let normalized = failureReason?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        if normalized.isEmpty { return false }
        let hints = [
            "timeout",
            "timed out",
            "try again",
            "temporarily unavailable",
            "service unavailable",
            "too many requests",
            "throttle",
            "unavailable"
        ]
        return hints.contains { normalized.contains($0) }
    }

    /// Transport / HTTP failures where card forwarding may succeed on retry.
    static func isRetryableCardForwardingTransportFailure(error: Error, statusCode: Int?) -> Bool {
        if let code = statusCode {
            if (500...599).contains(code) { return true }
            if code == 408 || code == 429 { return true }
            return false
        }
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return false }
        switch nsError.code {
        case NSURLErrorTimedOut,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorNotConnectedToInternet,
             NSURLErrorCannotFindHost,
             NSURLErrorCannotConnectToHost,
             NSURLErrorDNSLookupFailed:
            return true
        default:
            return false
        }
    }
}
