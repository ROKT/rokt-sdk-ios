import XCTest
@testable import Rokt_Widget

final class TestTxnConfiguration: XCTestCase {

    // MARK: - Gateway base URLs

    func test_gatewayBaseURL_stage() {
        XCTAssertEqual(TxnEnvironment.stage.gatewayBaseURL, "https://apps.stage.rokt.com")
    }

    func test_gatewayBaseURL_prod() {
        XCTAssertEqual(TxnEnvironment.prod.gatewayBaseURL, "https://apps.rokt.com")
    }

    func test_gatewayBaseURL_local() {
        XCTAssertEqual(TxnEnvironment.local.gatewayBaseURL, "http://localhost:9011")
    }

    func test_gatewayBaseURL_custom() {
        let custom = TxnEnvironment.custom(baseURL: "https://example.test")
        XCTAssertEqual(custom.gatewayBaseURL, "https://example.test")
    }

    // MARK: - Environment mapping

    func test_getEnvironment_stage() {
        XCTAssertEqual(TxnConfiguration.getEnvironment(.Stage), .stage)
    }

    func test_getEnvironment_prod() {
        XCTAssertEqual(TxnConfiguration.getEnvironment(.Prod), .prod)
    }

    func test_getEnvironment_local() {
        XCTAssertEqual(TxnConfiguration.getEnvironment(.Local), .local)
    }

    func test_getEnvironment_prodDemo_fallsBackToProd() {
        XCTAssertEqual(TxnConfiguration.getEnvironment(.ProdDemo), .prod)
    }

    func test_getEnvironment_mock_fallsBackToProd() {
        XCTAssertEqual(TxnConfiguration.getEnvironment(.Mock), .prod)
    }

    func test_getEnvironment_custom_preservesBaseURL() {
        XCTAssertEqual(
            TxnConfiguration.getEnvironment(.custom(baseURL: "https://example.test")),
            .custom(baseURL: "https://example.test")
        )
    }
}
