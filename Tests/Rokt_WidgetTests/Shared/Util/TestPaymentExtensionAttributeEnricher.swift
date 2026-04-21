import XCTest
@testable import Rokt_Widget

private let BE_IS_PAYMENT_EXTENSION_REGISTERED_KEY = "paymentExtensionRegistered"

class TestPaymentExtensionAttributeEnricher: XCTestCase {

    private var mockConfig: RoktConfig!

    override func setUp() {
        super.setUp()
        mockConfig = RoktConfig.Builder().build()
    }

    override func tearDown() {
        mockConfig = nil
        super.tearDown()
    }

    func testEnrich_withPaymentExtensionRegistered_shouldReturnTrue() {
        // Given
        let sut = PaymentExtensionAttributeEnricher(provider: { true })

        // When
        let attributes = sut.enrich(config: mockConfig)

        // Then
        XCTAssertEqual(attributes.count, 1, "Should contain one key.")
        XCTAssertEqual(
            attributes[BE_IS_PAYMENT_EXTENSION_REGISTERED_KEY], "true",
            "paymentExtensionActivated should be true when a payment extension is registered."
        )
    }

    func testEnrich_withNoPaymentExtensionRegistered_shouldReturnFalse() {
        // Given
        let sut = PaymentExtensionAttributeEnricher(provider: { false })

        // When
        let attributes = sut.enrich(config: mockConfig)

        // Then
        XCTAssertEqual(attributes.count, 1, "Should contain one key.")
        XCTAssertEqual(
            attributes[BE_IS_PAYMENT_EXTENSION_REGISTERED_KEY], "false",
            "paymentExtensionActivated should be false when no payment extension is registered."
        )
    }

    func testEnrich_withNilConfig_shouldStillReturnAttribute() {
        // Given
        let sut = PaymentExtensionAttributeEnricher(provider: { true })

        // When
        let attributes = sut.enrich(config: nil)

        // Then
        XCTAssertEqual(attributes.count, 1, "Should contain one key regardless of config.")
        XCTAssertEqual(attributes[BE_IS_PAYMENT_EXTENSION_REGISTERED_KEY], "true")
    }

    func testEnrich_providerIsCalledOnEachEnrich() {
        // Given
        var callCount = 0
        let sut = PaymentExtensionAttributeEnricher(provider: {
            callCount += 1
            return true
        })

        // When
        _ = sut.enrich(config: mockConfig)
        _ = sut.enrich(config: mockConfig)

        // Then
        XCTAssertEqual(callCount, 2, "Provider should be called on every enrich call.")
    }
}
