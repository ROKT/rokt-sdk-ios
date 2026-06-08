import Foundation

// Offline transport for the Mock environment: serves the bundled txn_init.json instead
// of the network, so the example app still exercises the real v2 decode + mapping path.
internal final class MockTxnInitHTTPClient: HTTPClientAdapter {
    enum MockError: Error {
        case fixtureMissing
    }

    private static let fixtureName = "txn_init"
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
        let result: RoktHTTPRequestResult

        if let fixtureURL = bundle.url(forResource: Self.fixtureName, withExtension: "json"),
           let data = try? Data(contentsOf: fixtureURL) {
            result = RoktHTTPRequestResult(
                httpURLResponse: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil),
                responseData: data,
                responseError: nil,
                jsonSerialisedResponseData: .success(NSNull())
            )
        } else {
            result = RoktHTTPRequestResult(
                httpURLResponse: nil,
                responseData: nil,
                responseError: MockError.fixtureMissing,
                jsonSerialisedResponseData: .failure(MockError.fixtureMissing)
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
