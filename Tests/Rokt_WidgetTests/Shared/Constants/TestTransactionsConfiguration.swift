import XCTest
@testable import Rokt_Widget

final class TestTransactionsConfiguration: XCTestCase {

    // MARK: - Gateway base URLs

    func test_gatewayBaseURL_stage() {
        XCTAssertEqual(TransactionsEnvironment.stage.gatewayBaseURL, "https://api.stage.rokt.com")
    }

    func test_gatewayBaseURL_prod() {
        XCTAssertEqual(TransactionsEnvironment.prod.gatewayBaseURL, "https://api.rokt.com")
    }

    func test_gatewayBaseURL_local() {
        XCTAssertEqual(TransactionsEnvironment.local.gatewayBaseURL, "http://localhost:9011")
    }

    func test_gatewayBaseURL_custom() {
        let custom = TransactionsEnvironment.custom(baseURL: "https://example.test")
        XCTAssertEqual(custom.gatewayBaseURL, "https://example.test")
    }

    // MARK: - RoktEnvironment mapping

    func test_getEnvironment_stage() {
        XCTAssertEqual(TransactionsConfiguration.getEnvironment(.Stage), .stage)
    }

    func test_getEnvironment_prod() {
        XCTAssertEqual(TransactionsConfiguration.getEnvironment(.Prod), .prod)
    }

    func test_getEnvironment_local() {
        XCTAssertEqual(TransactionsConfiguration.getEnvironment(.Local), .local)
    }

    func test_getEnvironment_prodDemo_fallsBackToProd() {
        XCTAssertEqual(TransactionsConfiguration.getEnvironment(.ProdDemo), .prod)
    }

    func test_getEnvironment_nil_fallsBackToProd() {
        XCTAssertEqual(TransactionsConfiguration.getEnvironment(nil), .prod)
    }
}
