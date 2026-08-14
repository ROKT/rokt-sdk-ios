import XCTest
@testable import Rokt_Widget

final class TestNetworkRetryRules: XCTestCase {

    private func urlError(_ code: Int) -> NSError {
        NSError(domain: NSURLErrorDomain, code: code)
    }

    private static let transientCodes = [
        NSURLErrorNetworkConnectionLost,
        NSURLErrorCannotConnectToHost,
        NSURLErrorCannotFindHost,
        NSURLErrorDNSLookupFailed
    ]

    func test_timeout_retryableUnderEveryPolicy() {
        let timeout = urlError(NSURLErrorTimedOut)
        XCTAssertTrue(NetworkRetryRules.isTransientTransportFailure(timeout, policy: .timeoutOnly))
        XCTAssertTrue(NetworkRetryRules.isTransientTransportFailure(timeout, policy: .transient))
        XCTAssertTrue(NetworkRetryRules.isTransientTransportFailure(timeout, policy: .transientIncludingOffline))
    }

    func test_transientCodes_excludedByTimeoutOnlyPolicy() {
        for code in Self.transientCodes {
            XCTAssertFalse(
                NetworkRetryRules.isTransientTransportFailure(urlError(code), policy: .timeoutOnly),
                "expected \(code) to be terminal for the legacy path"
            )
            XCTAssertTrue(
                NetworkRetryRules.isTransientTransportFailure(urlError(code), policy: .transient),
                "expected \(code) to be retryable"
            )
            XCTAssertTrue(
                NetworkRetryRules.isTransientTransportFailure(urlError(code), policy: .transientIncludingOffline),
                "expected \(code) to be retryable"
            )
        }
    }

    func test_notConnectedToInternet_onlyRetryableWhenRescheduled() {
        let offline = urlError(NSURLErrorNotConnectedToInternet)
        XCTAssertFalse(NetworkRetryRules.isTransientTransportFailure(offline, policy: .timeoutOnly))
        XCTAssertFalse(NetworkRetryRules.isTransientTransportFailure(offline, policy: .transient))
        XCTAssertTrue(NetworkRetryRules.isTransientTransportFailure(offline, policy: .transientIncludingOffline))
    }

    func test_permanentURLErrors_notRetryable() {
        let permanent = [
            NSURLErrorCancelled,
            NSURLErrorBadURL,
            NSURLErrorUnsupportedURL,
            NSURLErrorUserAuthenticationRequired,
            NSURLErrorSecureConnectionFailed,
            NSURLErrorServerCertificateUntrusted,
            NSURLErrorAppTransportSecurityRequiresSecureConnection
        ]
        for code in permanent {
            XCTAssertFalse(
                NetworkRetryRules.isTransientTransportFailure(urlError(code), policy: .transientIncludingOffline),
                "expected \(code) to be permanent"
            )
        }
    }

    func test_otherErrorDomains_notRetryable() {
        // A matching numeric code in another domain means something else entirely.
        let impostor = NSError(domain: NSCocoaErrorDomain, code: NSURLErrorTimedOut)
        XCTAssertFalse(NetworkRetryRules.isTransientTransportFailure(impostor, policy: .transientIncludingOffline))
        XCTAssertFalse(
            NetworkRetryRules.isTransientTransportFailure(
                TxnInitService.TxnInitError.missingResponseData,
                policy: .transientIncludingOffline
            )
        )
    }
}
