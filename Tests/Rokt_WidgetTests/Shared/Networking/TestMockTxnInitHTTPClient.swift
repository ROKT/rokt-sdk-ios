import XCTest
@testable import Rokt_Widget

final class TestMockTxnInitHTTPClient: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("txn-mock-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        super.tearDown()
    }

    private func writeFixture(_ json: String) {
        try? json.write(to: tempDir.appendingPathComponent("txn_init.json"), atomically: true, encoding: .utf8)
    }

    private func performRequest(bundle: Bundle) -> RoktHTTPRequestResult? {
        let client = MockTxnInitHTTPClient(bundle: bundle)
        let expectation = expectation(description: "completion")
        var captured: RoktHTTPRequestResult?
        client.startRequestWith(
            urlAddress: "https://apps.rokt.com/v2/config",
            method: .post,
            parameters: nil,
            parameterArray: nil,
            headers: nil,
            onRequestStart: nil,
            requestTimeout: nil,
            completionQueue: .main,
            completionHandler: { result in
                captured = result
                expectation.fulfill()
            }
        )
        wait(for: [expectation], timeout: 1)
        return captured
    }

    func test_servesBundledFixtureAs200() throws {
        writeFixture(
            """
            {
              "feature_flags": { "client-timeout-ms": 8000 },
              "fonts": []
            }
            """
        )
        let bundle = try XCTUnwrap(Bundle(url: tempDir))

        let result = performRequest(bundle: bundle)

        XCTAssertEqual(result?.httpURLResponse?.statusCode, 200)
        XCTAssertNil(result?.responseError)
        let data = try XCTUnwrap(result?.responseData)
        let decoded = try JSONDecoder().decode(TxnInitResponse.self, from: data)
        XCTAssertEqual(decoded.featureFlags.int(forKey: "client-timeout-ms"), 8000)
        XCTAssertEqual(decoded.fonts, [])
    }

    func test_missingFixture_servesEmbeddedDefaultAs200() throws {
        let bundle = try XCTUnwrap(Bundle(url: tempDir))

        let result = performRequest(bundle: bundle)

        XCTAssertEqual(result?.httpURLResponse?.statusCode, 200)
        XCTAssertNil(result?.responseError)
        let data = try XCTUnwrap(result?.responseData)
        let decoded = try JSONDecoder().decode(TxnInitResponse.self, from: data)
        XCTAssertEqual(decoded.featureFlags.int(forKey: "client-timeout-ms"), 8000)
    }
}
