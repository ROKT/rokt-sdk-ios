import XCTest
import Mocker
@testable import Rokt_Widget

/// Verifies the public-API-usage INFO diagnostics emitted on partner API calls.
final class TestPublicApiDiagnostics: XCTestCase {

    override func setUp() {
        super.setUp()
        // Satisfy the `roktTagId != nil` send guard without running a full init.
        Rokt.shared.roktImplementation.roktTagId = "123"
    }

    override func tearDown() {
        Mocker.removeAll()
        Rokt.shared.roktImplementation.roktTagId = nil
        super.tearDown()
    }

    func test_colorModeString_mapsEveryModeToBoundedNonPIIString() {
        XCTAssertEqual(RoktInternalImplementation.colorModeString(nil), "none")
        XCTAssertEqual(RoktInternalImplementation.colorModeString(RoktConfig.Builder().colorMode(.light).build()), "light")
        XCTAssertEqual(RoktInternalImplementation.colorModeString(RoktConfig.Builder().colorMode(.dark).build()), "dark")
        XCTAssertEqual(RoktInternalImplementation.colorModeString(RoktConfig.Builder().colorMode(.system).build()), "system")
    }

    func test_purchaseFinalized_sendsApiPurchaseFinalizedInfoDiagnostic() {
        let exp = expectation(description: "diagnostic received")
        var received: StubbedDiagnosticsModel?
        stubDiagnostics(onDiagnosticsModelReceive: { model in
            received = model
            exp.fulfill()
        })

        Rokt.shared.roktImplementation.purchaseFinalized(identifier: "id", catalogItemId: "cat", success: true)

        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(received?.code, "[API_PURCHASE_FINALIZED]")
        XCTAssertEqual(received?.severity, "INFO")
    }

    func test_bufferedApiCall_afterInit_sendsInline() {
        let exp = expectation(description: "diagnostic received")
        var code: String?
        stubDiagnostics(onDiagnosticsReceive: { code = $0; exp.fulfill() })

        Rokt.shared.roktImplementation.logApiCallBuffered(RoktInternalImplementation.apiSetCustomBaseURLCode)

        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(code, "[API_SET_CUSTOM_BASE_URL]")
    }

    func test_bufferedApiCall_beforeInit_doesNotSend() {
        Rokt.shared.roktImplementation.roktTagId = nil
        let exp = expectation(description: "no diagnostic before init")
        exp.isInverted = true
        stubDiagnostics(onDiagnosticsReceive: { _ in exp.fulfill() })

        Rokt.shared.roktImplementation.logApiCallBuffered(RoktInternalImplementation.apiSetFrameworkTypeCode)

        wait(for: [exp], timeout: 0.5)
    }
}
