import Foundation

struct OrderItem: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let price: Decimal
    let quantity: Int

    var total: Decimal { price * Decimal(quantity) }

    var formattedPrice: String {
        "$\(NSDecimalNumber(decimal: price).doubleValue.formatted(.number.precision(.fractionLength(2))))"
    }

    var formattedTotal: String {
        "$\(NSDecimalNumber(decimal: total).doubleValue.formatted(.number.precision(.fractionLength(2))))"
    }
}

extension OrderItem {
    static let sampleItems: [OrderItem] = [
        OrderItem(name: "Premium Headphones", description: "Wireless noise-cancelling", price: 149.99, quantity: 1),
        OrderItem(name: "Phone Case", description: "Protective silicone case", price: 29.99, quantity: 1)
    ]

    static var sampleTotal: String {
        let total = sampleItems.reduce(Decimal.zero) { $0 + $1.total }
        return "$\(NSDecimalNumber(decimal: total).doubleValue.formatted(.number.precision(.fractionLength(2))))"
    }
}
