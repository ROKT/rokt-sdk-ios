import XCTest
@testable import Rokt_Widget

final class TestTxnConfiguration: XCTestCase {

    // MARK: - Gateway base URLs

    func test_gatewayBaseURL_stage() {
        XCTAssertEqual(TxnEnvironment.stage.gatewayBaseURL, "https://api.stage.rokt.com")
    }

    func test_gatewayBaseURL_prod() {
        XCTAssertEqual(TxnEnvironment.prod.gatewayBaseURL, "https://api.rokt.com")
    }

    func test_gatewayBaseURL_local() {
        XCTAssertEqual(TxnEnvironment.local.gatewayBaseURL, "http://localhost:9011")
    }

    func test_gatewayBaseURL_custom() {
        let custom = TxnEnvironment.custom(baseURL: "https://example.test")
        XCTAssertEqual(custom.gatewayBaseURL, "https://example.test")
    }

    // MARK: - RoktEnvironment mapping

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

    func test_getEnvironment_nil_fallsBackToProd() {
        XCTAssertEqual(TxnConfiguration.getEnvironment(nil), .prod)
    }

    // MARK: - Build-configuration resolution

    func test_environment_resolvesFromBuildConfiguration() {
        var configuration = TxnConfiguration()
        // Resolved from the host's build configuration, which can only be stage or prod.
        let resolved = configuration.environment
        XCTAssertTrue(resolved == .prod || resolved == .stage)
    }
}
