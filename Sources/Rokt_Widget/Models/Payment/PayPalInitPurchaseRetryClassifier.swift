import Foundation

/// Client-side retry hints for the built-in PayPal Step-1 `/v1/cart/initialize-purchase` call.
///
/// Mirrors ``ForwardPaymentRetryRules/isRetryableForwardPaymentTransportFailure(error:statusCode:)``:
/// a transient transport / HTTP failure means the same initialize-purchase request may succeed on a
/// retry, so the offer should stay so the buyer can re-tap. Terminal failures (validation, other
/// 4xx, missing approval URL) are not retryable.
enum PayPalInitPurchaseRetryClassifier {
    /// Transport / HTTP failures where the same initialize-purchase request may succeed on retry.
    static func isRetryableInitPurchaseTransportFailure(error: Error, statusCode: Int?) -> Bool {
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
