import XCTest
import UIKit
import Mocker
import SafariServices
@testable import Rokt_Widget
@testable internal import RoktUXHelper

@MainActor
final class TestLinkHandler: XCTestCase {
    func testDefaultFailureReporterExcludesDestinationData() async {
        let originalTagId = Rokt.shared.roktImplementation.roktTagId
        let originalClient = NetworkingHelper.shared.httpClient
        defer {
            Mocker.removeAll()
            Rokt.shared.roktImplementation.roktTagId = originalTagId
            NetworkingHelper.shared.httpClient = originalClient
        }
        Rokt.shared.roktImplementation.roktTagId = "123"
        struct FailureCase {
            let url: String
            let type: RoktUXOpenURLType
            let reason: String
            let completes: Bool
        }
        let destination = "https://synthetic-user:synthetic-password@example.com/private/synthetic-id?token=synthetic-token#synthetic-fragment"
        let cases: [FailureCase] = [
            .init(url: "https://[?token=synthetic-token", type: .externally, reason: "Invalid URL", completes: true),
            .init(url: "exampleapp://product/synthetic-id?token=synthetic-token#synthetic-fragment",
                  type: .internally(sessionId: nil), reason: "Unsupported internal URL scheme", completes: false),
            .init(url: destination, type: .externally, reason: "External URL could not be opened", completes: true),
            .init(url: destination, type: .internally(sessionId: nil),
                  reason: "No view controller available for internal URL", completes: false)
        ]
        for testCase in cases {
            Mocker.removeAll()
            let diagnosticReceived = expectation(description: "URL diagnostic received")
            var diagnostic: StubbedDiagnosticsModel?
            stubDiagnostics(onDiagnosticsModelReceive: {
                diagnostic = $0
                diagnosticReceived.fulfill()
            })
            let opener = TestURLOpener()
            let handler = LinkHandler(openExternalURL: opener.open, presentingViewController: { nil })
            var completions = 0
            var errors = 0

            handler.linkHandler(urlString: testCase.url, type: testCase.type,
                                completionHandler: { completions += 1 }, failureHandler: { errors += 1 })
            if !opener.calls.isEmpty {
                XCTAssertEqual(opener.calls[0].url.absoluteString, testCase.url)
                opener.calls[0].complete(false)
                XCTAssertEqual(opener.calls.count, 2)
                XCTAssertEqual(opener.calls[1].url.absoluteString, testCase.url)
                opener.calls[1].complete(false)
            }

            await fulfillment(of: [diagnosticReceived], timeout: 5)
            XCTAssertEqual(diagnostic?.code, "[URL]")
            XCTAssertEqual(diagnostic?.stackTrace, testCase.reason)
            XCTAssertEqual(diagnostic?.severity, "ERROR")
            XCTAssertEqual(completions, testCase.completes ? 1 : 0)
            XCTAssertEqual(errors, 1)
        }
    }

    func testMissingPresenterReportsFailure() throws {
        let opener = TestURLOpener()
        let handler = LinkHandler(openExternalURL: opener.open, reportFailure: opener.reportFailure,
                                  presentingViewController: { nil })
        var completions = 0
        var errors = 0
        let url = try XCTUnwrap(URL(string: "https://example.com/product"))

        handler.linkHandler(urlString: url.absoluteString, type: .internally(sessionId: nil),
                            completionHandler: { completions += 1 }, failureHandler: { errors += 1 })

        XCTAssertEqual(errors, 1)
        XCTAssertEqual(completions, 0)
        XCTAssertEqual(opener.failures, ["No view controller available for internal URL"])
        XCTAssertTrue(opener.calls.isEmpty)
    }

    func testUniversalLinkStartsAfterCompletingOffer() throws {
        let opener = TestURLOpener()
        let handler = LinkHandler(openExternalURL: opener.open, reportFailure: opener.reportFailure)
        var completions = 0
        handler.linkHandler(urlString: "https://example.com/product", type: .externally,
                            completionHandler: { completions += 1 })
        XCTAssertEqual(completions, 1)
        XCTAssertEqual(opener.calls.count, 1)
        XCTAssertEqual(opener.calls[0].options[.universalLinksOnly] as? Bool, true)
        opener.calls[0].complete(true)
        opener.calls[0].complete(true)
        XCTAssertEqual(completions, 1)
        XCTAssertEqual(opener.calls.count, 1)
        XCTAssertTrue(opener.failures.isEmpty)
    }

    func testBrowserFallbackDoesNotRepeatCompletion() throws {
        let opener = TestURLOpener()
        let handler = LinkHandler(openExternalURL: opener.open, reportFailure: opener.reportFailure)
        var completions = 0
        handler.linkHandler(urlString: "https://example.com/product", type: .externally,
                            completionHandler: { completions += 1 })
        opener.calls[0].complete(false)
        opener.calls[0].complete(false)
        XCTAssertEqual(opener.calls.count, 2)
        XCTAssertEqual(completions, 1)
        XCTAssertNil(opener.calls[1].options[.universalLinksOnly])
        XCTAssertEqual(opener.calls[1].options[.init(rawValue: "isRokt")] as? Bool, true)
        XCTAssertEqual(opener.calls[0].url, opener.calls[1].url)
        opener.calls[1].complete(true)
        opener.calls[1].complete(true)
        XCTAssertEqual(completions, 1)
        XCTAssertTrue(opener.failures.isEmpty)
    }

    func testFailedOpenReportsFailureAfterCompletingOffer() throws {
        let opener = TestURLOpener()
        let handler = LinkHandler(openExternalURL: opener.open, reportFailure: opener.reportFailure)
        var completions = 0
        var errors = 0
        handler.linkHandler(urlString: "exampleapp://product/one", type: .externally,
                            completionHandler: { completions += 1 }, failureHandler: { errors += 1 })
        opener.calls[0].complete(false)
        opener.calls[1].complete(false)
        opener.calls[1].complete(true)
        XCTAssertEqual(completions, 1)
        XCTAssertEqual(errors, 1)
        XCTAssertEqual(opener.failures, ["External URL could not be opened"])
    }

    func testOverlappingExternalRequestsCompleteInRequestOrder() throws {
        let opener = TestURLOpener()
        let handler = LinkHandler(openExternalURL: opener.open, reportFailure: opener.reportFailure)
        var completed: [String] = []
        handler.linkHandler(urlString: "https://example.com/first", type: .externally,
                            completionHandler: { completed.append("first") })
        handler.linkHandler(urlString: "https://example.com/second", type: .externally,
                            completionHandler: { completed.append("second") })
        XCTAssertEqual(completed, ["first", "second"])
        opener.calls[1].complete(true)
        opener.calls[0].complete(true)
        XCTAssertEqual(completed, ["first", "second"])
    }

    func testOverlappingInternalRequestsKeepTheirOwnCompletion() throws {
        let presenter = TestPresenter()
        let handler = LinkHandler(presentingViewController: { presenter })
        var completed: [String] = []

        handler.linkHandler(urlString: "https://example.com/first", type: .internally(sessionId: nil),
                            completionHandler: { completed.append("first") })
        handler.linkHandler(urlString: "https://example.com/second", type: .internally(sessionId: nil),
                            completionHandler: { completed.append("second") })

        let first = try XCTUnwrap(presenter.presentations.first as? SFSafariViewController)
        let second = try XCTUnwrap(presenter.presentations.last as? SFSafariViewController)
        first.loadViewIfNeeded()
        second.loadViewIfNeeded()
        handler.safariViewControllerDidFinish(second)
        handler.safariViewControllerDidFinish(first)
        XCTAssertEqual(completed, ["second", "first"])
    }

    func testInternalCompletionIsReleasedWithSafariController() throws {
        let presenter = TestPresenter()
        let handler = LinkHandler(presentingViewController: { presenter })
        weak var capturedValue: NSObject?
        weak var safariController: SFSafariViewController?

        autoreleasepool {
            let value = NSObject()
            capturedValue = value
            handler.linkHandler(urlString: "https://example.com/product", type: .internally(sessionId: nil),
                                completionHandler: { _ = value })
            let presented = presenter.presentations.first as? SFSafariViewController
            presented?.loadViewIfNeeded()
            safariController = presented
            presenter.presentations.removeAll()
        }

        XCTAssertNil(safariController)
        XCTAssertNil(capturedValue)
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
        XCTAssertEqual(completions, 1)
        XCTAssertEqual(errors, 1)
        XCTAssertTrue(opener.calls.isEmpty)
        XCTAssertEqual(opener.failures, ["Invalid URL"])
    }

    func testOpenEventPreservesExternalProgressionAndReportsFailure() {
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
            XCTAssertEqual(closedIDs, ["product-response"])
            XCTAssertTrue(errorIDs.isEmpty)
            opener.calls[0].complete(false)
            opener.calls[1].complete(succeeds)
            XCTAssertEqual(closedIDs, ["product-response"])
            XCTAssertEqual(errorIDs, succeeds ? [] : ["product-response"])
            XCTAssertEqual(reportedError?.domain, succeeds ? nil : "com.rokt.sdk.url")
            XCTAssertEqual(reportedError?.code, succeeds ? nil : 1)
        }
    }
}

private final class TestPresenter: UIViewController {
    var presentations: [UIViewController] = []

    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool,
                          completion: (() -> Void)? = nil) {
        presentations.append(viewControllerToPresent)
        completion?()
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
