import Foundation

/// Formats the order breakdown values pushed into the UXHelper layout's
/// `DATA.catalogRuntime.*` placeholders by ``RoktUX/devicePayShowConfirmation``.
///
/// Subtotal is summed from ``UpsellItem/totalPrice`` (the response echoes back
/// what the SDK sent in `/v1/cart/initialize-purchase`); shipping / tax / total
/// come straight from the cart-prepare response's ``PaymentDetails``.
enum BreakdownFormatter {
    static let subtotalKey = "subtotal"
    static let taxKey = "tax"
    static let shippingKey = "shipping"
    static let totalKey = "total"

    /// Build the `[String: String]` payload for ``RoktUX/devicePayShowConfirmation``.
    static func format(
        upsellItems: [UpsellItem],
        shippingCost: Decimal,
        tax: Decimal,
        totalAmount: Decimal,
        currency: String,
        locale: Locale = .current
    ) -> [String: String] {
        let subtotal = upsellItems.reduce(Decimal(0)) { $0 + $1.totalPrice }
        let formatter = currencyFormatter(currency: currency, locale: locale)
        return [
            subtotalKey: format(subtotal, formatter: formatter),
            taxKey: format(tax, formatter: formatter),
            shippingKey: format(shippingCost, formatter: formatter),
            totalKey: format(totalAmount, formatter: formatter)
        ]
    }

    private static func currencyFormatter(currency: String, locale: Locale) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = currency
        return formatter
    }

    private static func format(_ amount: Decimal, formatter: NumberFormatter) -> String {
        let number = NSDecimalNumber(decimal: amount)
        return formatter.string(from: number) ?? "\(amount)"
    }
}
