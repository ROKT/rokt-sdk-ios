import XCTest
import RoktContracts
@testable import Rokt_Widget

private let BE_IS_PAYMENT_EXTENSION_REGISTERED_KEY = "paymentExtensionRegistered"
private let BE_AVAILABLE_PAYMENT_METHODS_KEY = "availablePaymentMethods"

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
        let sut = PaymentExtensionAttributeEnricher(
            provider: { true },
            availablePaymentMethodsProvider: { [.card, .paypal] }
        )

        // When
        let attributes = sut.enrich(config: mockConfig)

        // Then
        XCTAssertEqual(attributes.count, 2, "Should contain payment extension and available payment method keys.")
        XCTAssertEqual(
            attributes[BE_IS_PAYMENT_EXTENSION_REGISTERED_KEY], "true",
            "paymentExtensionRegistered should be true when a payment extension is registered."
        )
    }

    func testEnrich_withNoPaymentExtensionRegistered_shouldReturnFalse() {
        // Given
        let sut = PaymentExtensionAttributeEnricher(
            provider: { false },
            availablePaymentMethodsProvider: { [.card, .paypal] }
        )

        // When
        let attributes = sut.enrich(config: mockConfig)

        // Then
        XCTAssertEqual(attributes.count, 2, "Should contain payment extension and available payment method keys.")
        XCTAssertEqual(
            attributes[BE_IS_PAYMENT_EXTENSION_REGISTERED_KEY], "false",
            "paymentExtensionRegistered should be false when no payment extension is registered."
        )
    }

    func testEnrich_withNilConfig_shouldStillReturnAttribute() {
        // Given
        let sut = PaymentExtensionAttributeEnricher(
            provider: { true },
            availablePaymentMethodsProvider: { [.card, .paypal] }
        )

        // When
        let attributes = sut.enrich(config: nil)

        // Then
        XCTAssertEqual(attributes.count, 2, "Should contain both keys regardless of config.")
        XCTAssertEqual(attributes[BE_IS_PAYMENT_EXTENSION_REGISTERED_KEY], "true")
    }

    func testEnrich_withAvailablePaymentMethods_shouldReturnWireValues() {
        // Given
        let methods: [PaymentMethodType] = [.applePay, .card, .paypal]
        let sut = PaymentExtensionAttributeEnricher(
            provider: { true },
            availablePaymentMethodsProvider: { methods }
        )

        // When
        let attributes = sut.enrich(config: mockConfig)

        // Then
        XCTAssertEqual(attributes[BE_AVAILABLE_PAYMENT_METHODS_KEY], methods.map(\.wireValue).joined(separator: ","))
    }

    func testEnrich_providerIsCalledOnEachEnrich() {
        // Given
        var callCount = 0
        let sut = PaymentExtensionAttributeEnricher(provider: {
            callCount += 1
            return true
        }, availablePaymentMethodsProvider: {
            [.card, .paypal]
        })

        // When
        _ = sut.enrich(config: mockConfig)
        _ = sut.enrich(config: mockConfig)

        // Then
        XCTAssertEqual(callCount, 2, "Provider should be called on every enrich call.")
    }
}
