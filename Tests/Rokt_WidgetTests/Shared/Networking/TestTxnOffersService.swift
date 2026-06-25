import XCTest
@testable import Rokt_Widget

/// Covers the offers service end to end with a stubbed transport: a successful
/// response is decoded, rolls the session token forward, and is adapted into the
/// experience string the renderer consumes; an unexpected status surfaces as a
/// failure with its status code.
final class TestTxnOffersService: XCTestCase {

    private final class StubHTTPClient: HTTPClientAdapter {
        let responseData: Data?
        let statusCode: Int

        init(responseData: Data?, statusCode: Int) {
            self.responseData = responseData
            self.statusCode = statusCode
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
            let url = URL(string: urlAddress) ?? URL(string: Environment.Prod.gatewayBaseURL)!
            let result = RoktHTTPRequestResult(
                httpURLResponse: HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil),
                responseData: responseData,
                responseError: nil,
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
        responseData: Data?,
        statusCode: Int,
        sessionManager: TxnSessionManager
    ) -> TxnOffersService {
        TxnOffersService(
            environment: .Prod,
            accountId: "account-1",
            sdkVersion: "1.0.0",
            sessionManager: sessionManager,
            httpClient: StubHTTPClient(responseData: responseData, statusCode: statusCode),
            maxRetries: 0,
            sleep: { _ in }
        )
    }

    func test_getExperienceData_adaptsResponseAndRollsTokenForward() {
        let sessionManager = TxnSessionManager()
        let service = makeService(
            responseData: Data(offersResponse.utf8),
            statusCode: 200,
            sessionManager: sessionManager
        )

        let completed = expectation(description: "offers experience returned")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { page in
            let page = page ?? ""
            // Adapter output is the renderer's experience contract.
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

    func test_getExperienceData_reportsFailureWithStatusCode() {
        let service = makeService(responseData: nil, statusCode: 500, sessionManager: TxnSessionManager())

        let failed = expectation(description: "offers failed")
        service.getExperienceData(viewName: "checkout", attributes: [:], config: nil, successLayout: { _ in
            XCTFail("unexpected success")
        }, failure: { _, statusCode, _ in
            XCTAssertEqual(statusCode, 500)
            failed.fulfill()
        })

        wait(for: [failed], timeout: 5)
    }
}
