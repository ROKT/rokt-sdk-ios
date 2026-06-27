import Foundation

// Offline transport for the Mock environment: serves a v2 init response without the network
// so the SDK still exercises the real decode + mapping path. Falls back to a built-in
// response so Mock init never depends on a host-bundled fixture (a bundled init.json
// overrides the default when present, which the example app uses).
internal final class MockInitHTTPClient: HTTPClientAdapter {
    private static let fixtureName = "init"

    // Guaranteed success response, mirroring the hard-coded init the legacy mock path returned.
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

    // periphery:ignore - required by HTTPClientAdapter; v2 init never downloads files
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
