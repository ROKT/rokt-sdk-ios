import XCTest
@testable import Rokt_Widget
@testable internal import RoktUXHelper

/// Tests for `RoktInternalImplementation.resolveForwardPaymentPrices`, which
/// derives unit + total prices from a forward-payment event. The event may
/// carry either price independently; the SDK must reconstruct the missing one
/// from `quantity` rather than silently aliasing one to the other.
final class TestForwardPaymentPriceResolution: XCTestCase {

    private func makeEvent(
        quantity: Decimal = 1,
        unitPrice: Decimal? = Decimal(string: "9.99"),
        totalPrice: Decimal? = Decimal(string: "19.98"),
        partnerPaymentReference: String? = "partner-ref"
    ) -> RoktUXEvent.CartItemForwardPayment {
        RoktUXEvent.CartItemForwardPayment(
            layoutId: "layout-123",
            name: "Test Product",
            cartItemId: "cart-item-123",
            catalogItemId: "catalog-item-123",
            currency: "USD",
            description: "A test product",
            linkedProductId: nil,
            providerData: "{}",
            quantity: quantity,
            totalPrice: totalPrice,
            unitPrice: unitPrice,
            partnerPaymentReference: partnerPaymentReference
        )
    }

    func test_resolvesBothPrices_whenBothProvided() {
        let prices = RoktInternalImplementation.resolveForwardPaymentPrices(
            unitPrice: Decimal(string: "9.99"),
            totalPrice: Decimal(string: "19.98"),
            quantity: 2
        )

        XCTAssertEqual(prices?.unitPrice, Decimal(string: "9.99"))
        XCTAssertEqual(prices?.totalPrice, Decimal(string: "19.98"))
    }

    func test_derivesTotalPrice_whenOnlyUnitPriceProvided() {
        let prices = RoktInternalImplementation.resolveForwardPaymentPrices(
            unitPrice: Decimal(string: "9.99"),
            totalPrice: nil,
            quantity: 3
        )

        XCTAssertEqual(prices?.unitPrice, Decimal(string: "9.99"))
        XCTAssertEqual(prices?.totalPrice, Decimal(string: "29.97"))
    }

    func test_derivesUnitPrice_whenOnlyTotalPriceProvided() {
        let prices = RoktInternalImplementation.resolveForwardPaymentPrices(
            unitPrice: nil,
            totalPrice: Decimal(string: "30.00"),
            quantity: 3
        )

        XCTAssertEqual(prices?.unitPrice, Decimal(string: "10.00"))
        XCTAssertEqual(prices?.totalPrice, Decimal(string: "30.00"))
    }

    func test_derivesUnitPrice_equalsTotal_whenQuantityIsOne() {
        let prices = RoktInternalImplementation.resolveForwardPaymentPrices(
            unitPrice: nil,
            totalPrice: Decimal(string: "19.88"),
            quantity: 1
        )

        XCTAssertEqual(prices?.unitPrice, Decimal(string: "19.88"))
        XCTAssertEqual(prices?.totalPrice, Decimal(string: "19.88"))
    }

    func test_returnsNil_whenNeitherPriceProvided() {
        let prices = RoktInternalImplementation.resolveForwardPaymentPrices(
            unitPrice: nil,
            totalPrice: nil,
            quantity: 1
        )

        XCTAssertNil(prices)
    }

    func test_returnsNil_whenOnlyTotalPrice_andQuantityZero() {
        let prices = RoktInternalImplementation.resolveForwardPaymentPrices(
            unitPrice: nil,
            totalPrice: Decimal(string: "19.88"),
            quantity: 0
        )

        XCTAssertNil(prices)
    }

    func test_returnsNil_whenOnlyTotalPrice_andQuantityNegative() {
        let prices = RoktInternalImplementation.resolveForwardPaymentPrices(
            unitPrice: nil,
            totalPrice: Decimal(string: "19.88"),
            quantity: -1
        )

        XCTAssertNil(prices)
    }

    func test_preservesUnitPrice_evenWhenQuantityIsZero_ifUnitProvided() {
        // We only guard quantity when deriving unitPrice from totalPrice.
        // When unitPrice is provided, quantity is used as-is for the derived
        // totalPrice (would be 0 here); let the API validate semantics.
        let prices = RoktInternalImplementation.resolveForwardPaymentPrices(
            unitPrice: Decimal(string: "9.99"),
            totalPrice: nil,
            quantity: 0
        )

        XCTAssertEqual(prices?.unitPrice, Decimal(string: "9.99"))
        XCTAssertEqual(prices?.totalPrice, Decimal.zero)
    }

    func test_buildForwardPaymentRequest_returnsNil_whenPricesCannotBeResolved() {
        let request = RoktInternalImplementation.buildForwardPaymentRequest(
            from: makeEvent(quantity: 0, unitPrice: nil, totalPrice: Decimal(string: "19.98"))
        )

        XCTAssertNil(request)
    }

    func test_buildForwardPaymentRequest_buildsRequestFromResolvedPrices() {
        let request = try? XCTUnwrap(
            RoktInternalImplementation.buildForwardPaymentRequest(
                from: makeEvent(quantity: 3, unitPrice: nil, totalPrice: Decimal(string: "30.00"))
            )
        )

        XCTAssertEqual(request?.totalUpsellPrice, Decimal(string: "30.00"))
        XCTAssertEqual(request?.currency, "USD")
        XCTAssertEqual(request?.upsellItems.first?.quantity, 3)
        XCTAssertEqual(request?.upsellItems.first?.unitPrice, Decimal(string: "10.00"))
        XCTAssertEqual(request?.upsellItems.first?.totalPrice, Decimal(string: "30.00"))
        XCTAssertEqual(request?.paymentDetails.partnerPaymentReference, "partner-ref")
    }

    func test_buildForwardPaymentRequest_preservesNilPartnerPaymentReference() {
        let request = try? XCTUnwrap(
            RoktInternalImplementation.buildForwardPaymentRequest(
                from: makeEvent(partnerPaymentReference: nil)
            )
        )

        XCTAssertNil(request?.paymentDetails.partnerPaymentReference)
        XCTAssertNil(request?.paymentDetails.token)
        XCTAssertNil(request?.fulfillmentDetails)
    }

    func test_resolveForwardPaymentFinalization_returnsSuccessWithoutFailureReason() {
        let finalization = RoktInternalImplementation.resolveForwardPaymentFinalization(
            from: PurchaseResponse(success: true, reason: "ignored")
        )

        XCTAssertTrue(finalization.success)
        XCTAssertNil(finalization.failureReason)
    }

    func test_resolveForwardPaymentFinalization_usesResponseReason_whenBusinessFailureProvided() {
        let finalization = RoktInternalImplementation.resolveForwardPaymentFinalization(
            from: PurchaseResponse(success: false, reason: "PaymentDetailsInvalid")
        )

        XCTAssertFalse(finalization.success)
        XCTAssertEqual(finalization.failureReason, "PaymentDetailsInvalid")
    }

    func test_resolveForwardPaymentFinalization_fallsBack_whenBusinessFailureReasonMissing() {
        let finalization = RoktInternalImplementation.resolveForwardPaymentFinalization(
            from: PurchaseResponse(success: false, reason: nil)
        )

        XCTAssertFalse(finalization.success)
        XCTAssertEqual(
            finalization.failureReason,
            RoktInternalImplementation.unknownForwardPaymentFailureReason
        )
    }

    func test_resolveForwardPaymentFinalization_fromFailureMessage_usesProvidedMessage() {
        let finalization = RoktInternalImplementation.resolveForwardPaymentFinalization(
            fromFailureMessage: "Gateway unavailable"
        )

        XCTAssertFalse(finalization.success)
        XCTAssertEqual(finalization.failureReason, "Gateway unavailable")
    }

    func test_resolveForwardPaymentFinalization_fromFailureMessage_fallsBack_whenEmpty() {
        let finalization = RoktInternalImplementation.resolveForwardPaymentFinalization(
            fromFailureMessage: ""
        )

        XCTAssertFalse(finalization.success)
        XCTAssertEqual(
            finalization.failureReason,
            RoktInternalImplementation.unknownForwardPaymentFailureReason
        )
    }
}
