import XCTest
@testable import Rokt_Widget

/// The Mock-environment offers transport serves an offline response that still
/// decodes through the real `SelectResponse` path, so Mock builds exercise the
/// same decode + adapt the live path does.
final class TestMockOffersHTTPClient: XCTestCase {

    func test_servesA200ThatDecodesAsSelectResponse() {
        let client = MockOffersHTTPClient()

        let completed = expectation(description: "mock offers response delivered")
        client.startRequestWith(
            urlAddress: "\(Environment.Prod.gatewayBaseURL)/v2/sessions/offers",
            method: .post,
            parameters: nil,
            parameterArray: nil,
            headers: nil,
            onRequestStart: nil,
            requestTimeout: nil,
            completionQueue: .main
        ) { result in
            XCTAssertEqual(result.httpURLResponse?.statusCode, 200)
            let data = result.responseData ?? Data()
            let decoded = try? JSONDecoder().decode(SelectResponse.self, from: data)
            XCTAssertNotNil(decoded, "mock offers response should decode as SelectResponse")
            XCTAssertFalse(decoded?.sessionToken.token.isEmpty ?? true)
            completed.fulfill()
        }

        wait(for: [completed], timeout: 5)
    }

    func test_servesBundledFixtureWhenPresent() {
        // The test bundle ships offers.json, so the bundled fixture wins over the
        // built-in default and still decodes through the real path.
        let client = MockOffersHTTPClient(bundle: .module)
        let expected = try? Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: "offers", withExtension: "json")))

        let completed = expectation(description: "bundled offers fixture delivered")
        client.startRequestWith(
            urlAddress: "\(Environment.Prod.gatewayBaseURL)/v2/sessions/offers",
            method: .post,
            parameters: nil,
            parameterArray: nil,
            headers: nil,
            onRequestStart: nil,
            requestTimeout: nil,
            completionQueue: .main
        ) { result in
            XCTAssertEqual(result.responseData, expected, "bundled offers.json should be served verbatim")
            XCTAssertNotNil(try? JSONDecoder().decode(SelectResponse.self, from: result.responseData ?? Data()))
            completed.fulfill()
        }

        wait(for: [completed], timeout: 5)
    }

    func test_updateTimeoutAndDownloadFileAreNoOps() {
        // Required by HTTPClientAdapter but unused by the offline offers transport.
        let client = MockOffersHTTPClient()
        client.updateTimeout(timeout: 5)
        client.downloadFile(
            source: "https://example.com",
            destinationURL: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("unused"),
            options: [],
            parameters: nil,
            headers: nil,
            requestTimeout: nil,
            completionQueue: .main,
            completionHandler: nil
        )
    }
}
