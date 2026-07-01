import XCTest
@testable import Rokt_Widget

final class TestPayPalInitPurchaseRetryClassifier: XCTestCase {

    func test_serverErrors_retryable() {
        let err = NSError(domain: "test", code: 1)
        XCTAssertTrue(PayPalInitPurchaseRetryClassifier.isRetryableInitPurchaseTransportFailure(error: err, statusCode: 500))
        XCTAssertTrue(PayPalInitPurchaseRetryClassifier.isRetryableInitPurchaseTransportFailure(error: err, statusCode: 503))
        XCTAssertTrue(PayPalInitPurchaseRetryClassifier.isRetryableInitPurchaseTransportFailure(error: err, statusCode: 408))
        XCTAssertTrue(PayPalInitPurchaseRetryClassifier.isRetryableInitPurchaseTransportFailure(error: err, statusCode: 429))
    }

    func test_clientErrors_notRetryable() {
        let err = NSError(domain: "test", code: 1)
        XCTAssertFalse(PayPalInitPurchaseRetryClassifier.isRetryableInitPurchaseTransportFailure(error: err, statusCode: 400))
        XCTAssertFalse(PayPalInitPurchaseRetryClassifier.isRetryableInitPurchaseTransportFailure(error: err, statusCode: 404))
        XCTAssertFalse(PayPalInitPurchaseRetryClassifier.isRetryableInitPurchaseTransportFailure(error: err, statusCode: 422))
    }

    func test_nilStatusCode_usesURLErrorDomain() {
        let timedOut = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        XCTAssertTrue(PayPalInitPurchaseRetryClassifier.isRetryableInitPurchaseTransportFailure(error: timedOut, statusCode: nil))

        let notConnected = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        XCTAssertTrue(PayPalInitPurchaseRetryClassifier.isRetryableInitPurchaseTransportFailure(
            error: notConnected,
            statusCode: nil
        ))

        let connectionLost = NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost)
        XCTAssertTrue(PayPalInitPurchaseRetryClassifier.isRetryableInitPurchaseTransportFailure(
            error: connectionLost,
            statusCode: nil
        ))

        let dnsFailure = NSError(domain: NSURLErrorDomain, code: NSURLErrorDNSLookupFailed)
        XCTAssertTrue(PayPalInitPurchaseRetryClassifier.isRetryableInitPurchaseTransportFailure(
            error: dnsFailure,
            statusCode: nil
        ))

        let other = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL)
        XCTAssertFalse(PayPalInitPurchaseRetryClassifier.isRetryableInitPurchaseTransportFailure(error: other, statusCode: nil))

        let nonURL = NSError(domain: "RoktSDK", code: -1)
        XCTAssertFalse(PayPalInitPurchaseRetryClassifier.isRetryableInitPurchaseTransportFailure(error: nonURL, statusCode: nil))
    }
}
