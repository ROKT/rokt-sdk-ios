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

    func test_colorModeDiagnosticValue_mapsEveryModeToBoundedNonPIIString() {
        let missingConfig: RoktConfig? = nil
        XCTAssertEqual(missingConfig?.colorModeDiagnosticValue ?? "none", "none")
        XCTAssertEqual(RoktConfig.Builder().colorMode(.light).build().colorModeDiagnosticValue, "light")
        XCTAssertEqual(RoktConfig.Builder().colorMode(.dark).build().colorModeDiagnosticValue, "dark")
        XCTAssertEqual(RoktConfig.Builder().colorMode(.system).build().colorModeDiagnosticValue, "system")
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

    func test_bufferedApiCall_beforeInit_isDrainedOnceWhenTagIdIsSet() {
        let implementation = RoktInternalImplementation()
        implementation.logApiCallBuffered(RoktInternalImplementation.apiSetFrameworkTypeCode)

        let logs = implementation.setRoktTagIdAndDrainPendingApiLogs("123")

        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.code, "[API_SET_FRAMEWORK_TYPE]")
        XCTAssertTrue(implementation.setRoktTagIdAndDrainPendingApiLogs("123").isEmpty)
    }

    func test_logMParticleApiCall_sendsPrefixedInfoDiagnosticWithNoAdditionalInfo() {
        let exp = expectation(description: "diagnostic received")
        var received: StubbedDiagnosticsModel?
        stubDiagnostics(onDiagnosticsModelReceive: { received = $0; exp.fulfill() })

        Rokt.logMParticleApiCall("LOG_EVENT")

        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(received?.code, "[MP_API_LOG_EVENT]")
        XCTAssertEqual(received?.severity, "INFO")
    }

    func test_logMParticleApiCall_dropsMalformedCode_doesNotSend() {
        let exp = expectation(description: "no diagnostic for malformed code")
        exp.isInverted = true
        stubDiagnostics(onDiagnosticsReceive: { _ in exp.fulfill() })

        // Lowercase, spaces, PII-shaped, empty, and over-length are all rejected by the guard.
        Rokt.logMParticleApiCall("log_event")
        Rokt.logMParticleApiCall("user email@example.com")
        Rokt.logMParticleApiCall("")
        Rokt.logMParticleApiCall(String(repeating: "A", count: 41))

        wait(for: [exp], timeout: 0.5)
    }

    func test_isValidMParticleApiCode_boundsShapeToUppercaseSnakeCase() {
        XCTAssertTrue(RoktInternalImplementation.isValidMParticleApiCode("LOG_EVENT"))
        XCTAssertTrue(RoktInternalImplementation.isValidMParticleApiCode("SET_USER_ATTRIBUTE_LIST"))
        XCTAssertTrue(RoktInternalImplementation.isValidMParticleApiCode("A"))
        XCTAssertFalse(RoktInternalImplementation.isValidMParticleApiCode("log_event"))
        XCTAssertFalse(RoktInternalImplementation.isValidMParticleApiCode("_LEADING_UNDERSCORE"))
        XCTAssertFalse(RoktInternalImplementation.isValidMParticleApiCode("HAS SPACE"))
        XCTAssertFalse(RoktInternalImplementation.isValidMParticleApiCode("user@x.com"))
        XCTAssertFalse(RoktInternalImplementation.isValidMParticleApiCode(""))
        XCTAssertFalse(RoktInternalImplementation.isValidMParticleApiCode(String(repeating: "A", count: 41)))
    }
}
