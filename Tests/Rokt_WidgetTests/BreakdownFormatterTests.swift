import XCTest
@testable import Rokt_Widget

final class BreakdownFormatterTests: XCTestCase {
    private let usLocale = Locale(identifier: "en_US")

    private func upsellItem(unitPrice: Decimal, quantity: Decimal = 1) -> UpsellItem {
        UpsellItem(
            cartItemId: "cart1",
            catalogItemId: "cat1",
            quantity: quantity,
            unitPrice: unitPrice,
            totalPrice: unitPrice * quantity,
            currency: "USD"
        )
    }

    func test_format_subtotalSumsUpsellItemTotalPrices() {
        let breakdown = BreakdownFormatter.format(
            upsellItems: [
                upsellItem(unitPrice: 10),
                upsellItem(unitPrice: 5, quantity: 3)
            ],
            shippingCost: 0,
            tax: 0,
            totalAmount: 25,
            currency: "USD",
            locale: usLocale
        )

        XCTAssertEqual(breakdown[BreakdownFormatter.subtotalKey], "$25.00")
    }

    func test_format_USDproducesExpectedKeys() {
        let breakdown = BreakdownFormatter.format(
            upsellItems: [upsellItem(unitPrice: Decimal(string: "24.00")!)],
            shippingCost: 0,
            tax: Decimal(string: "1.94")!,
            totalAmount: Decimal(string: "25.94")!,
            currency: "USD",
            locale: usLocale
        )

        XCTAssertEqual(breakdown[BreakdownFormatter.subtotalKey], "$24.00")
        XCTAssertEqual(breakdown[BreakdownFormatter.shippingKey], "$0.00")
        XCTAssertEqual(breakdown[BreakdownFormatter.taxKey], "$1.94")
        XCTAssertEqual(breakdown[BreakdownFormatter.totalKey], "$25.94")
    }

    func test_format_EURusesProvidedCurrencyCode() {
        let breakdown = BreakdownFormatter.format(
            upsellItems: [upsellItem(unitPrice: 12)],
            shippingCost: 3,
            tax: 1,
            totalAmount: 16,
            currency: "EUR",
            locale: usLocale
        )

        XCTAssertEqual(breakdown[BreakdownFormatter.totalKey], "€16.00")
        XCTAssertEqual(breakdown[BreakdownFormatter.shippingKey], "€3.00")
    }

    func test_format_zeroShippingAndTax() {
        let breakdown = BreakdownFormatter.format(
            upsellItems: [upsellItem(unitPrice: 9)],
            shippingCost: 0,
            tax: 0,
            totalAmount: 9,
            currency: "USD",
            locale: usLocale
        )

        XCTAssertEqual(breakdown[BreakdownFormatter.subtotalKey], "$9.00")
        XCTAssertEqual(breakdown[BreakdownFormatter.shippingKey], "$0.00")
        XCTAssertEqual(breakdown[BreakdownFormatter.taxKey], "$0.00")
        XCTAssertEqual(breakdown[BreakdownFormatter.totalKey], "$9.00")
    }

    func test_format_emptyUpsellItemsYieldsZeroSubtotal() {
        let breakdown = BreakdownFormatter.format(
            upsellItems: [],
            shippingCost: 0,
            tax: 0,
            totalAmount: 0,
            currency: "USD",
            locale: usLocale
        )

        XCTAssertEqual(breakdown[BreakdownFormatter.subtotalKey], "$0.00")
    }
}
