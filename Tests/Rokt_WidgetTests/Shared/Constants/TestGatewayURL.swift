import XCTest
@testable import Rokt_Widget

final class TestGatewayURL: XCTestCase {

    func test_gatewayBaseURL_stage() {
        XCTAssertEqual(Environment.Stage.gatewayBaseURL, "https://apps.stage.rokt.com")
    }

    func test_gatewayBaseURL_prod() {
        XCTAssertEqual(Environment.Prod.gatewayBaseURL, "https://apps.rokt.com")
    }

    func test_gatewayBaseURL_local() {
        XCTAssertEqual(Environment.Local.gatewayBaseURL, "http://localhost:9011")
    }

    func test_gatewayBaseURL_custom_preservesBaseURL() {
        XCTAssertEqual(Environment.custom(baseURL: "https://example.test").gatewayBaseURL, "https://example.test")
    }

    func test_gatewayBaseURL_mock_reusesProd() {
        XCTAssertEqual(Environment.Mock.gatewayBaseURL, "https://apps.rokt.com")
    }

    func test_gatewayBaseURL_prodDemo_usesDemoHost() {
        XCTAssertEqual(Environment.ProdDemo.gatewayBaseURL, "https://mobile-api-demo.rokt.com")
    }
}
