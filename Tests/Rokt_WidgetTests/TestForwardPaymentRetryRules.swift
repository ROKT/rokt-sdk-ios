import XCTest
@testable import Rokt_Widget

final class TestForwardPaymentRetryRules: XCTestCase {

    func test_isForwardPaymentBusinessFailureRetryable_nilAndEmpty_notRetryable() {
        XCTAssertFalse(ForwardPaymentRetryRules.isForwardPaymentBusinessFailureRetryable(failureReason: nil))
        XCTAssertFalse(ForwardPaymentRetryRules.isForwardPaymentBusinessFailureRetryable(failureReason: ""))
        XCTAssertFalse(ForwardPaymentRetryRules.isForwardPaymentBusinessFailureRetryable(failureReason: "   "))
    }

    func test_isForwardPaymentBusinessFailureRetryable_declined_notRetryable() {
        XCTAssertFalse(ForwardPaymentRetryRules.isForwardPaymentBusinessFailureRetryable(failureReason: "declined"))
    }

    func test_isForwardPaymentBusinessFailureRetryable_hintSubstrings_retryable() {
        let hints = [
            "Request timeout",
            "The operation timed out",
            "Please try again later",
            "TEMPORARILY UNAVAILABLE",
            "service unavailable",
            "Too many requests",
            "Throttled",
            "Service unavailable"
        ]
        for reason in hints {
            XCTAssertTrue(
                ForwardPaymentRetryRules.isForwardPaymentBusinessFailureRetryable(failureReason: reason),
                "Expected retryable: \(reason)"
            )
        }
    }

    func test_isRetryableForwardPaymentTransportFailure_serverErrors_retryable() {
        let err = NSError(domain: "test", code: 1)
        XCTAssertTrue(ForwardPaymentRetryRules.isRetryableForwardPaymentTransportFailure(error: err, statusCode: 500))
        XCTAssertTrue(ForwardPaymentRetryRules.isRetryableForwardPaymentTransportFailure(error: err, statusCode: 503))
        XCTAssertTrue(ForwardPaymentRetryRules.isRetryableForwardPaymentTransportFailure(error: err, statusCode: 408))
        XCTAssertTrue(ForwardPaymentRetryRules.isRetryableForwardPaymentTransportFailure(error: err, statusCode: 429))
    }

    func test_isRetryableForwardPaymentTransportFailure_clientErrors_notRetryable() {
        let err = NSError(domain: "test", code: 1)
        XCTAssertFalse(ForwardPaymentRetryRules.isRetryableForwardPaymentTransportFailure(error: err, statusCode: 400))
        XCTAssertFalse(ForwardPaymentRetryRules.isRetryableForwardPaymentTransportFailure(error: err, statusCode: 404))
    }

    func test_isRetryableForwardPaymentTransportFailure_nilStatusCode_usesURLErrorDomain() {
        let retryable = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        XCTAssertTrue(ForwardPaymentRetryRules.isRetryableForwardPaymentTransportFailure(error: retryable, statusCode: nil))

        let notConnected = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        XCTAssertTrue(ForwardPaymentRetryRules.isRetryableForwardPaymentTransportFailure(error: notConnected, statusCode: nil))

        let other = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL)
        XCTAssertFalse(ForwardPaymentRetryRules.isRetryableForwardPaymentTransportFailure(error: other, statusCode: nil))

        let nonURL = NSError(domain: "RoktSDK", code: -1)
        XCTAssertFalse(ForwardPaymentRetryRules.isRetryableForwardPaymentTransportFailure(error: nonURL, statusCode: nil))
    }
}
