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
}
