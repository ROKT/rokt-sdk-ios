import XCTest
@testable import Rokt_Widget

/// Tests for `RoktInternalImplementation.resolveForwardPaymentPrices`, which
/// derives unit + total prices from a forward-payment event. The event may
/// carry either price independently; the SDK must reconstruct the missing one
/// from `quantity` rather than silently aliasing one to the other.
final class TestForwardPaymentPriceResolution: XCTestCase {

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
}
