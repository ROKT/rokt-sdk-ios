import Foundation

// Offline transport for the Mock environment: serves an offers selection response without
// the network so the SDK still exercises the real decode + adapt + render path. Falls back
// to a built-in response so Mock offers never depend on a host-bundled fixture (a bundled
// offers.json overrides the default when present, which the example app uses).
internal final class MockOffersHTTPClient: HTTPClientAdapter {
    private static let fixtureName = "offers"

    private static let defaultResponse = Data(
        """
        {
          "session_id": "mock-session-00000000-0000-7000-8000-000000000000",
          "session_token": { "token": "mock-session-token", "expires_at": 32503680000000 },
          "page_instance_guid": "mock-page-instance-00000000-0000-7000-8000-000000000000",
          "page_context": {
            "page_instance_guid": "mock-page-instance-00000000-0000-7000-8000-000000000000",
            "page_id": "mock-page",
            "token": "mock-page-token"
          },
          "plugins": [
            {
              "plugin": {
                "id": "mock-plugin-1",
                "name": "dcui",
                "target_element_selector": "#rokt",
                "config": {
                  "instance_guid": "mock-plugin-instance-1",
                  "token": "mock-plugin-token",
                  "outer_layout_schema": "{\\"layout\\":{\\"node\\":\\"outer\\"}}",
                  "slots": [
                    {
                      "instance_guid": "mock-slot-1",
                      "token": "mock-slot-token",
                      "layout_variant": {
                        "layout_variant_id": "mock-layout-variant-1",
                        "module_name": "dcui",
                        "layout_variant_schema": "{\\"node\\":\\"root\\"}"
                      }
                    }
                  ]
                }
              }
            }
          ]
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

    // periphery:ignore - required by HTTPClientAdapter; offers never downloads files
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
