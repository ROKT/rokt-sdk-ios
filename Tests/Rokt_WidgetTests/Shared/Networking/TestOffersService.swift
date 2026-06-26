import XCTest
@testable import Rokt_Widget

/// Covers the offers service with a stubbed transport: a successful response is
/// decoded, rolls the session token forward, and is adapted into the experience
/// string the renderer consumes; retryable statuses are retried; an unexpected
/// status or missing body surfaces as a failure; and the request carries the
/// derived privacy control and sanitised attributes.
final class TestOffersService: XCTestCase {

    /// One stubbed transport outcome: body + status, or a transport-level error.
    private struct StubResponse {
        let data: Data?
        let status: Int
        let error: Error?
        init(data: Data?, status: Int, error: Error? = nil) {
            self.data = data
            self.status = status
            self.error = error
        }
    }

    private final class StubHTTPClient: HTTPClientAdapter {
        private let responses: [StubResponse]
        private(set) var requestCount = 0
        private(set) var lastParameters: RoktHTTPParameters?
        private(set) var lastHeaders: RoktHTTPHeaders?

        init(responseData: Data?, statusCode: Int) {
            responses = [StubResponse(data: responseData, status: statusCode)]
        }

        init(responses: [(data: Data?, status: Int)]) {
            self.responses = responses.map { StubResponse(data: $0.data, status: $0.status) }
        }

        init(sequence: [StubResponse]) {
            responses = sequence
        }

        func updateTimeout(timeout: Double) {}

        @discardableResult
        func startRequestWith(
            urlAddress: String,
            method: RoktHTTPMethod,
            parameters: RoktHTTPParameters?,
            parameterArray: RoktHTTPParameterArray?,
            headers: RoktHTTPHeaders?,
            onRequestStart: (() -> Void)?,
            requestTimeout: TimeInterval?,
            completionQueue: DispatchQueue,
            completionHandler: ((RoktHTTPRequestResult) -> Void)?
        ) -> URLRequest? {
            lastParameters = parameters
            lastHeaders = headers
            let response = responses[min(requestCount, responses.count - 1)]
            requestCount += 1
            let url = URL(string: urlAddress) ?? URL(string: Environment.Prod.gatewayBaseURL)!
            let result = RoktHTTPRequestResult(
                httpURLResponse: HTTPURLResponse(url: url, statusCode: response.status, httpVersion: nil, headerFields: nil),
                responseData: response.data,
                responseError: response.error,
                jsonSerialisedResponseData: .success(NSNull())
            )
            completionQueue.async { completionHandler?(result) }
            return nil
        }

        func downloadFile(
            source urlAddress: String,
            destinationURL: URL,
            options: [RoktDownloadOptions],
            parameters: RoktHTTPParameters?,
            headers: RoktHTTPHeaders?,
            requestTimeout: TimeInterval?,
            completionQueue: DispatchQueue,
            completionHandler: ((RoktDownloadResult) -> Void)?
        ) {}
    }

    private let offersResponse = """
    {
      "session_id": "session-1",
      "session_token": { "token": "rolled-token", "expires_at": 32503680000000 },
      "page_instance_guid": "pig-1",
      "page_context": { "page_id": "checkout", "token": "page-token" },
      "plugins": [
        { "plugin": { "id": "plugin-1", "config": {
          "token": "plugin-token",
          "outer_layout_schema": "{\\"layout\\":{\\"node\\":\\"outer\\"}}",
          "slots": []
        } } }
      ]
    }
    """

    private func makeService(
        _ stub: StubHTTPClient,
        sessionManager: TxnSessionManager = TxnSessionManager(),
        maxRetries: Int = 0
    ) -> OffersService {
        OffersService(
            environment: .Prod,
            accountId: "account-1",
            sdkVersion: "1.0.0",
            sessionManager: sessionManager,
            httpClient: stub,
            maxRetries: maxRetries,
            sleep: { _ in }
        )
    }

    func test_getExperienceData_adaptsResponseAndRollsTokenForward() {
        let sessionManager = TxnSessionManager()
        let service = makeService(StubHTTPClient(responseData: Data(offersResponse.utf8), statusCode: 200),
                                  sessionManager: sessionManager)

        let completed = expectation(description: "offers experience returned")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { page in
            let page = page ?? ""
            XCTAssertTrue(page.contains("\"placementContext\""))
            XCTAssertTrue(page.contains("\"rolled-token\""))
            completed.fulfill()
        }, failure: { error, _, _ in
            XCTFail("unexpected failure: \(error)")
        })

        wait(for: [completed], timeout: 5)
        // The refreshed token is rolled forward for the next call.
        XCTAssertEqual(sessionManager.authorizationHeader, "Bearer rolled-token")
    }

    func test_getExperienceData_retriesRetryableStatusThenSucceeds() {
        let stub = StubHTTPClient(responses: [(nil, 503), (Data(offersResponse.utf8), 200)])
        let service = makeService(stub, maxRetries: 1)

        let completed = expectation(description: "offers retried then succeeded")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { page in
            XCTAssertNotNil(page)
            completed.fulfill()
        }, failure: { error, _, _ in
            XCTFail("unexpected failure: \(error)")
        })

        wait(for: [completed], timeout: 5)
        XCTAssertEqual(stub.requestCount, 2)
    }

    func test_getExperienceData_reportsFailureWithStatusCode() {
        let service = makeService(StubHTTPClient(responseData: nil, statusCode: 500))

        let failed = expectation(description: "offers failed")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { _ in
            XCTFail("unexpected success")
        }, failure: { _, statusCode, _ in
            XCTAssertEqual(statusCode, 500)
            failed.fulfill()
        })

        wait(for: [failed], timeout: 5)
    }

    func test_getExperienceData_failsWhenResponseBodyMissing() {
        let service = makeService(StubHTTPClient(responseData: nil, statusCode: 200))

        let failed = expectation(description: "missing body fails")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { _ in
            XCTFail("unexpected success")
        }, failure: { _, _, _ in
            failed.fulfill()
        })

        wait(for: [failed], timeout: 5)
    }

    func test_getExperienceData_buildsPrivacyControlAndSanitisesAttributesAndFiresOnRequestStart() {
        let stub = StubHTTPClient(responseData: Data(offersResponse.utf8), statusCode: 200)
        let service = makeService(stub)

        var onRequestStartFired = false
        let completed = expectation(description: "request built")
        service.getExperienceData(
            viewName: "checkout",
            attributes: ["noFunctional": "true", "doNotShareOrSell": "false", "email": "a@b.com"],
            config: nil,
            onRequestStart: { onRequestStartFired = true },
            successLayout: { _ in completed.fulfill() },
            failure: { error, _, _ in XCTFail("unexpected failure: \(error)") }
        )

        wait(for: [completed], timeout: 5)
        XCTAssertTrue(onRequestStartFired)

        let body = try? XCTUnwrap(stub.lastParameters as? [String: Any])
        let privacy = body?["privacy_control"] as? [String: Any]
        XCTAssertEqual(privacy?["no_functional"] as? Bool, true)
        XCTAssertEqual(privacy?["do_not_share_or_sell"] as? Bool, false)

        let attributes = body?["attributes"] as? [String: Any]
        XCTAssertEqual(attributes?["email"] as? String, "a@b.com")
        // Privacy keys are stripped from the forwarded attributes.
        XCTAssertNil(attributes?["noFunctional"])
    }

    func test_getExperienceData_retriesTransientTransportErrorThenSucceeds() {
        let timeout = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        let stub = StubHTTPClient(sequence: [
            StubResponse(data: nil, status: 0, error: timeout),
            StubResponse(data: Data(offersResponse.utf8), status: 200)
        ])
        let service = makeService(stub, maxRetries: 1)

        let completed = expectation(description: "transient transport error retried then succeeded")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { page in
            XCTAssertNotNil(page)
            completed.fulfill()
        }, failure: { error, _, _ in
            XCTFail("unexpected failure: \(error)")
        })

        wait(for: [completed], timeout: 5)
        XCTAssertEqual(stub.requestCount, 2)
    }

    func test_getExperienceData_doesNotRetryNonTransportError() {
        let nonTransport = NSError(domain: "Custom", code: 1)
        let stub = StubHTTPClient(sequence: [StubResponse(data: nil, status: 0, error: nonTransport)])
        let service = makeService(stub, maxRetries: 2)

        let failed = expectation(description: "non-transport error fails without retry")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { _ in
            XCTFail("unexpected success")
        }, failure: { _, _, _ in
            failed.fulfill()
        })

        wait(for: [failed], timeout: 5)
        XCTAssertEqual(stub.requestCount, 1)
    }

    func test_getExperienceData_doesNotRetryNonRetryableURLError() {
        // A URL-domain error whose code is outside the transient set must fail fast.
        let badResponse = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse)
        let stub = StubHTTPClient(sequence: [StubResponse(data: nil, status: 0, error: badResponse)])
        let service = makeService(stub, maxRetries: 2)

        let failed = expectation(description: "non-retryable URL error fails without retry")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { _ in
            XCTFail("unexpected success")
        }, failure: { _, _, _ in
            failed.fulfill()
        })

        wait(for: [failed], timeout: 5)
        XCTAssertEqual(stub.requestCount, 1)
    }

    func test_getExperienceData_usesDefaultBackoffSleepWhenNotInjected() {
        // Build the service without injecting `sleep` so the real backoff closure runs
        // during the retry; a tiny backoff keeps the delay negligible.
        let stub = StubHTTPClient(responses: [(nil, 503), (Data(offersResponse.utf8), 200)])
        let service = OffersService(
            environment: .Prod,
            accountId: "account-1",
            sdkVersion: "1.0.0",
            sessionManager: TxnSessionManager(),
            httpClient: stub,
            maxRetries: 1,
            baseBackoff: 0.001
        )

        let completed = expectation(description: "default backoff sleep used on retry")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { page in
            XCTAssertNotNil(page)
            completed.fulfill()
        }, failure: { error, _, _ in
            XCTFail("unexpected failure: \(error)")
        })

        wait(for: [completed], timeout: 5)
        XCTAssertEqual(stub.requestCount, 2)
    }
}
