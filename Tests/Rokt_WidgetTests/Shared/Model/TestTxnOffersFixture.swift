import XCTest
@testable import Rokt_Widget

/// Guards the bundled mock offers fixture (`txn_offers.json`): proves it decodes
/// into `TxnSelectResponse` and that its response-option `action` / `signal_type`
/// values are ones the renderer recognizes. Mirrors Android's `TxnOffersFixtureTest`
/// — the same fixture seeds the offline mock offers path, so an unrecognized
/// action (or a fixture that fails to decode) silently breaks that path.
final class TestTxnOffersFixture: XCTestCase {

    // Values the renderer's `Action` / `RoktUXSignalType` enums recognize; the
    // mapper later coerces anything outside them to `.unknown`.
    private let recognizedActions: Set<String> = ["Url", "CaptureOnly", "ExternalPaymentTrigger"]
    private let recognizedSignalTypes: Set<String> = ["SignalResponse", "SignalGatedResponse"]

    private func loadFixture() throws -> TxnSelectResponse {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "txn_offers", withExtension: "json"),
            "txn_offers.json missing from the test bundle"
        )
        return try JSONDecoder().decode(TxnSelectResponse.self, from: Data(contentsOf: url))
    }

    private func responseOptions(_ response: TxnSelectResponse) -> [TxnSelectResponseOption] {
        (response.plugins ?? [])
            .compactMap { $0.plugin?.config?.slots }
            .flatMap { $0 }
            .compactMap { $0.offer?.creative?.responseOptionsMap?.values }
            .flatMap { Array($0) }
    }

    func test_fixtureDecodesIntoSelectResponse() throws {
        let response = try loadFixture()

        XCTAssertFalse(response.sessionId.isEmpty)
        XCTAssertFalse(response.sessionToken.token.isEmpty)

        let config = try XCTUnwrap(response.plugins?.first?.plugin?.config)
        XCTAssertFalse(config.slots.isEmpty)
        // DCUI schemas stay as pre-serialized strings.
        XCTAssertFalse(try XCTUnwrap(config.outerLayoutSchema).isEmpty)

        let slot = try XCTUnwrap(config.slots.first)
        XCTAssertFalse(try XCTUnwrap(slot.layoutVariant?.layoutVariantSchema).isEmpty)
        XCTAssertNotNil(slot.offer?.creative)
    }

    func test_fixtureResponseOptionsUseRecognizedActionAndSignalType() throws {
        let options = responseOptions(try loadFixture())

        XCTAssertFalse(options.isEmpty)
        for option in options {
            XCTAssertTrue(
                recognizedActions.contains(try XCTUnwrap(option.action)),
                "Unrecognized action: \(option.action ?? "nil")"
            )
            XCTAssertTrue(
                recognizedSignalTypes.contains(try XCTUnwrap(option.signalType)),
                "Unrecognized signal_type: \(option.signalType ?? "nil")"
            )
        }
    }

    func test_fixtureEventDataDecodesTypedRealTimeEvents() throws {
        let response = try loadFixture()

        let entry = try XCTUnwrap(response.eventData?["mock-creative-instance-1"])
        XCTAssertFalse(entry.token.isEmpty)

        let event = try XCTUnwrap(entry.events?["SignalResponse"])
        XCTAssertEqual(event.eventType, "SignalResponse")
        XCTAssertNotNil(event.payload)
    }
}
