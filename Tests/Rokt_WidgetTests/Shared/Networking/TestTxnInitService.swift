import XCTest
@testable import Rokt_Widget

final class TestTxnInitService: XCTestCase {

    private var httpClient: MockTxnHTTPClient!

    override func setUp() {
        super.setUp()
        httpClient = MockTxnHTTPClient()
    }

    override func tearDown() {
        httpClient = nil
        super.tearDown()
    }

    private func makeService(environment: Environment = .Prod, maxRetries: Int = 3) -> TxnInitService {
        TxnInitService(
            environment: environment,
            accountId: "account-1",
            sdkVersion: "5.2.2",
            layoutSchemaVersion: "2.3",
            httpClient: httpClient,
            maxRetries: maxRetries,
            baseBackoff: 0,
            sleep: { _ in }
        )
    }

    // Config-only payload — no session_id / session_token. A session block in
    // the JSON would simply be ignored by the decoder.
    private func successJSON() -> Data {
        Data(
            """
            {
              "feature_flags": {
                "rokt-tracking-status": true,
                "client-timeout-ms": 30000,
                "mobile-sdk-use-bounding-box": false,
                "minimum-post-purchase-schema": "2.3.0"
              },
              "fonts": []
            }
            """.utf8
        )
    }

    func test_initSession_success_decodesFeatureFlags() async throws {
        httpClient.results = [.success(data: successJSON())]
        let result = try await makeService().initSession()

        XCTAssertTrue(result.featureFlags.isEnabled(.roktTrackingStatus))
        XCTAssertTrue(result.featureFlags.isEnabled(.minimumPostPurchaseSchema))
        XCTAssertEqual(httpClient.capturedHeaders.count, 1)
    }

    func test_initSession_sendsHeaderInputs_andNoAuthorization() async throws {
        httpClient.results = [.success(data: successJSON())]

        _ = try await makeService().initSession()

        let headers = httpClient.capturedHeaders.first
        // Body-less GET: inputs travel as headers.
        XCTAssertEqual(headers?["rokt-account-id"], "account-1")
        XCTAssertEqual(headers?["rokt-os-type"], "ios")
        XCTAssertEqual(headers?["rokt-sdk-version"], "5.2.2")
        XCTAssertEqual(headers?["rokt-layout-schema-version"], "2.3")
        // Config-only is unauthenticated: never send Authorization.
        XCTAssertNil(headers?["Authorization"])
    }

    func test_initSession_retriesOnTransient5xx_thenSucceeds() async throws {
        httpClient.results = [.status(500), .status(503), .status(504), .success(data: successJSON())]

        _ = try await makeService().initSession()

        XCTAssertEqual(httpClient.callCount, 4)
    }

    func test_initSession_retriesOnTimeout_thenSucceeds() async throws {
        httpClient.results = [.transport(NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)),
                              .success(data: successJSON())]

        _ = try await makeService().initSession()

        XCTAssertEqual(httpClient.callCount, 2)
    }

    func test_initSession_exhaustsRetries_throwsUnexpectedStatus() async {
        httpClient.results = [.status(503)]

        do {
            _ = try await makeService(maxRetries: 3).initSession()
            XCTFail("Expected init to fail after exhausting retries")
        } catch let error as TxnInitService.TxnInitError {
            XCTAssertEqual(error, .unexpectedStatusCode(503))
            XCTAssertEqual(httpClient.callCount, 4)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_initSession_nonRetryableStatus_doesNotRetry() async {
        httpClient.results = [.status(400)]

        do {
            _ = try await makeService().initSession()
            XCTFail("Expected init to fail on 400")
        } catch let error as TxnInitService.TxnInitError {
            XCTAssertEqual(error, .unexpectedStatusCode(400))
            XCTAssertEqual(httpClient.callCount, 1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_initSession_offline_isNotRetried() async {
        httpClient.results = [.transport(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet))]

        do {
            _ = try await makeService().initSession()
            XCTFail("Expected init to fail when offline")
        } catch {
            XCTAssertEqual(httpClient.callCount, 1)
        }
    }

    func test_initSession_decodeError_propagatesWithoutRetry() async {
        httpClient.results = [.success(data: Data("not json".utf8))]

        do {
            _ = try await makeService().initSession()
            XCTFail("Expected decoding to fail")
        } catch is DecodingError {
            XCTAssertEqual(httpClient.callCount, 1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_initSession_invalidBaseURL_throws() async {
        let service = makeService(environment: .custom(baseURL: "ht tp://bad url"))

        do {
            _ = try await service.initSession()
            XCTFail("Expected invalid base URL to fail")
        } catch let error as TxnInitService.TxnInitError {
            XCTAssertEqual(error, .invalidBaseURL)
            XCTAssertEqual(httpClient.callCount, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private final class MockTxnHTTPClient: HTTPClientAdapter {
    enum Response {
        case success(data: Data)
        case status(Int)
        case transport(Error)
    }

    var results: [Response] = []
    private(set) var callCount = 0
    private(set) var capturedHeaders: [RoktHTTPHeaders] = []
    private(set) var timeout: Double?

    func updateTimeout(timeout: Double) {
        self.timeout = timeout
    }

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
        capturedHeaders.append(headers ?? [:])
        let response = results[min(callCount, results.count - 1)]
        callCount += 1

        let url = URL(string: urlAddress) ?? URL(string: "https://apps.rokt.com")!
        let result: RoktHTTPRequestResult
        switch response {
        case .success(let data):
            result = RoktHTTPRequestResult(
                httpURLResponse: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil),
                responseData: data,
                responseError: nil,
                jsonSerialisedResponseData: .success(NSNull())
            )
        case .status(let code):
            result = RoktHTTPRequestResult(
                httpURLResponse: HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil),
                responseData: nil,
                responseError: nil,
                jsonSerialisedResponseData: .success(NSNull())
            )
        case .transport(let error):
            result = RoktHTTPRequestResult(
                httpURLResponse: nil,
                responseData: nil,
                responseError: error,
                jsonSerialisedResponseData: .failure(error)
            )
        }

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
