import XCTest
@testable import Rokt_Widget

final class TestCardForwardingRetryRules: XCTestCase {

    func test_isCardForwardingErrorRetryable_nilAndEmpty_notRetryable() {
        XCTAssertFalse(CardForwardingRetryRules.isCardForwardingErrorRetryable(failureReason: nil))
        XCTAssertFalse(CardForwardingRetryRules.isCardForwardingErrorRetryable(failureReason: ""))
        XCTAssertFalse(CardForwardingRetryRules.isCardForwardingErrorRetryable(failureReason: "   "))
    }

    func test_isCardForwardingErrorRetryable_declined_notRetryable() {
        XCTAssertFalse(CardForwardingRetryRules.isCardForwardingErrorRetryable(failureReason: "declined"))
    }

    func test_isCardForwardingErrorRetryable_hintSubstrings_retryable() {
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
                CardForwardingRetryRules.isCardForwardingErrorRetryable(failureReason: reason),
                "Expected retryable: \(reason)"
            )
        }
    }

    func test_isRetryableCardForwardingTransportFailure_serverErrors_retryable() {
        let err = NSError(domain: "test", code: 1)
        XCTAssertTrue(CardForwardingRetryRules.isRetryableCardForwardingTransportFailure(error: err, statusCode: 500))
        XCTAssertTrue(CardForwardingRetryRules.isRetryableCardForwardingTransportFailure(error: err, statusCode: 503))
        XCTAssertTrue(CardForwardingRetryRules.isRetryableCardForwardingTransportFailure(error: err, statusCode: 408))
        XCTAssertTrue(CardForwardingRetryRules.isRetryableCardForwardingTransportFailure(error: err, statusCode: 429))
    }

    func test_isRetryableCardForwardingTransportFailure_clientErrors_notRetryable() {
        let err = NSError(domain: "test", code: 1)
        XCTAssertFalse(CardForwardingRetryRules.isRetryableCardForwardingTransportFailure(error: err, statusCode: 400))
        XCTAssertFalse(CardForwardingRetryRules.isRetryableCardForwardingTransportFailure(error: err, statusCode: 404))
    }

    func test_isRetryableCardForwardingTransportFailure_nilStatusCode_usesURLErrorDomain() {
        let retryable = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        XCTAssertTrue(CardForwardingRetryRules.isRetryableCardForwardingTransportFailure(error: retryable, statusCode: nil))

        let notConnected = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        XCTAssertTrue(CardForwardingRetryRules.isRetryableCardForwardingTransportFailure(error: notConnected, statusCode: nil))

        let other = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL)
        XCTAssertFalse(CardForwardingRetryRules.isRetryableCardForwardingTransportFailure(error: other, statusCode: nil))

        let nonURL = NSError(domain: "RoktSDK", code: -1)
        XCTAssertFalse(CardForwardingRetryRules.isRetryableCardForwardingTransportFailure(error: nonURL, statusCode: nil))
    }
}
