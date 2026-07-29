#if DEBUG
import Foundation

// Offline mock transport for init responses. Development-only (Environment.Mock);
// compiled out of release builds so it never ships in the SDK.
internal final class MockTxnInitHTTPClient: HTTPClientAdapter {
    private static let fixtureName = "txn_init"

    private static let defaultResponse = Data(
        """
        {
          "session_id": "mock-session-00000000-0000-7000-8000-000000000000",
          "session_token": { "token": "mock-session-token", "expires_at": 32503680000000 },
          "feature_flags": {
            "client-timeout-ms": 8000,
            "rokt-tracking-status": true,
            "mobile-sdk-use-bounding-box": true,
            "mobile-sdk-use-sdk-cache": true,
            "is-post-purchase-enabled": true,
            "minimum-post-purchase-schema": "2.3.0"
          },
          "fonts": []
        }
        """.utf8
    )

    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
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
        onRequestStart?()

        let url = URL(string: urlAddress) ?? URL(string: Environment.Prod.gatewayBaseURL)!
        let result = RoktHTTPRequestResult(
            httpURLResponse: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil),
            responseData: bundledFixture() ?? Self.defaultResponse,
            responseError: nil,
            jsonSerialisedResponseData: .success(NSNull())
        )

        completionQueue.async { completionHandler?(result) }
        return nil
    }

    private func bundledFixture() -> Data? {
        guard let fixtureURL = bundle.url(forResource: Self.fixtureName, withExtension: "json") else { return nil }
        return try? Data(contentsOf: fixtureURL)
    }

    // periphery:ignore - required by HTTPClientAdapter; init never downloads files
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
#endif
