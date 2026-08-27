import XCTest
import UIKit
@testable import Rokt_Widget
@testable internal import RoktUXHelper

@MainActor
final class TestLinkHandler: XCTestCase {
    func testUniversalLinkCompletesOnlyAfterOpeningSucceeds() throws {
        let opener = TestURLOpener()
        let handler = LinkHandler(openExternalURL: opener.open, reportFailure: opener.reportFailure)
        var completions = 0
        handler.linkHandler(urlString: "https://example.com/product", type: .externally,
                            completionHandler: { completions += 1 })
        XCTAssertEqual(completions, 0)
        XCTAssertEqual(opener.calls.count, 1)
        XCTAssertEqual(opener.calls[0].options[.universalLinksOnly] as? Bool, true)
        opener.calls[0].complete(true)
        opener.calls[0].complete(true)
        XCTAssertEqual(completions, 1)
        XCTAssertEqual(opener.calls.count, 1)
        XCTAssertTrue(opener.failures.isEmpty)
    }

    func testBrowserFallbackCompletesOnlyAfterItsSuccess() throws {
        let opener = TestURLOpener()
        let handler = LinkHandler(openExternalURL: opener.open, reportFailure: opener.reportFailure)
        var completions = 0
        handler.linkHandler(urlString: "https://example.com/product", type: .externally,
                            completionHandler: { completions += 1 })
        opener.calls[0].complete(false)
        opener.calls[0].complete(false)
        XCTAssertEqual(opener.calls.count, 2)
        XCTAssertEqual(completions, 0)
        XCTAssertNil(opener.calls[1].options[.universalLinksOnly])
        XCTAssertEqual(opener.calls[1].options[.init(rawValue: "isRokt")] as? Bool, true)
        XCTAssertEqual(opener.calls[0].url, opener.calls[1].url)
        opener.calls[1].complete(true)
        opener.calls[1].complete(true)
        XCTAssertEqual(completions, 1)
        XCTAssertTrue(opener.failures.isEmpty)
    }

    func testFailedOpenReportsFailureWithoutCompletingOffer() throws {
        let opener = TestURLOpener()
        let handler = LinkHandler(openExternalURL: opener.open, reportFailure: opener.reportFailure)
        var completions = 0
        var errors = 0
        handler.linkHandler(urlString: "exampleapp://product/one", type: .externally,
                            completionHandler: { completions += 1 }, failureHandler: { errors += 1 })
        opener.calls[0].complete(false)
        opener.calls[1].complete(false)
        opener.calls[1].complete(true)
        XCTAssertEqual(completions, 0)
        XCTAssertEqual(errors, 1)
        XCTAssertEqual(opener.failures, ["exampleapp://product/one"])
    }

    func testOverlappingRequestsKeepTheirOwnCompletion() throws {
        let opener = TestURLOpener()
        let handler = LinkHandler(openExternalURL: opener.open, reportFailure: opener.reportFailure)
        var completed: [String] = []
        handler.linkHandler(urlString: "https://example.com/first", type: .externally,
                            completionHandler: { completed.append("first") })
        handler.linkHandler(urlString: "https://example.com/second", type: .externally,
                            completionHandler: { completed.append("second") })
        opener.calls[1].complete(true)
        opener.calls[0].complete(true)
        XCTAssertEqual(completed, ["second", "first"])
    }

    func testUnsupportedInternalURLReportsFailure() throws {
        let opener = TestURLOpener()
        let handler = LinkHandler(openExternalURL: opener.open, reportFailure: opener.reportFailure)
        var completions = 0
        var errors = 0
        handler.linkHandler(urlString: "exampleapp://product/one", type: .internally(sessionId: nil),
                            completionHandler: { completions += 1 }, failureHandler: { errors += 1 })
        XCTAssertEqual(completions, 0)
        XCTAssertEqual(errors, 1)
        XCTAssertTrue(opener.calls.isEmpty)
        XCTAssertEqual(opener.failures.count, 1)
    }

    func testMalformedURLReportsFailureWithoutOpening() {
        let opener = TestURLOpener()
        let handler = LinkHandler(openExternalURL: opener.open, reportFailure: opener.reportFailure)
        var completions = 0
        var errors = 0
        handler.linkHandler(urlString: "https://[", type: .externally,
                            completionHandler: { completions += 1 }, failureHandler: { errors += 1 })
        XCTAssertEqual(completions, 0)
        XCTAssertEqual(errors, 1)
        XCTAssertTrue(opener.calls.isEmpty)
        XCTAssertEqual(opener.failures, ["https://["])
    }

    func testOpenEventForwardsSuccessfulCloseAndFailedOpenSeparately() {
        for succeeds in [false, true] {
            let opener = TestURLOpener()
            let handler = LinkHandler(openExternalURL: opener.open, reportFailure: opener.reportFailure)
            let implementation = RoktInternalImplementation(linkHandler: handler)
            var closedIDs: [String] = []
            var errorIDs: [String] = []
            var reportedError: NSError?
            let event = RoktUXEvent.OpenUrl(url: "https://example.com/product", id: "product-response",
                                            layoutId: "example-layout", type: .externally,
                                            onClose: { closedIDs.append($0) },
                                            onError: { id, error in
                errorIDs.append(id)
                reportedError = error.map { $0 as NSError }
            })
            implementation.callOnRoktUXEvent("example-execute", uxEvent: event)
            XCTAssertTrue(closedIDs.isEmpty)
            XCTAssertTrue(errorIDs.isEmpty)
            opener.calls[0].complete(false)
            opener.calls[1].complete(succeeds)
            XCTAssertEqual(closedIDs, succeeds ? ["product-response"] : [])
            XCTAssertEqual(errorIDs, succeeds ? [] : ["product-response"])
            XCTAssertEqual(reportedError?.domain, succeeds ? nil : "com.rokt.sdk.url")
            XCTAssertEqual(reportedError?.code, succeeds ? nil : 1)
        }
    }
}

private final class TestURLOpener {
    struct Call {
        let url: URL
        let options: [UIApplication.OpenExternalURLOptionsKey: Any]
        let complete: (Bool) -> Void
    }
    var calls: [Call] = []
    var failures: [String] = []

    func open(_ url: URL, options: [UIApplication.OpenExternalURLOptionsKey: Any], completion: @escaping (Bool) -> Void) {
        calls.append(Call(url: url, options: options, complete: completion))
    }

    func reportFailure(_ url: String) {
        failures.append(url)
    }
}
