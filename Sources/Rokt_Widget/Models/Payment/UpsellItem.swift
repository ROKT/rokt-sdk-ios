import Foundation

struct UpsellItem: Decodable {
    let cartItemId: String
    let catalogItemId: String
    let quantity: Decimal
    let unitPrice: Decimal
    let totalPrice: Decimal
    let currency: String

    init(
        cartItemId: String,
        catalogItemId: String,
        quantity: Decimal,
        unitPrice: Decimal,
        totalPrice: Decimal,
        currency: String
    ) {
        self.cartItemId = cartItemId
        self.catalogItemId = catalogItemId
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalPrice = totalPrice
        self.currency = currency
    }

    func toDictionary() -> [String: Any] {
        [
            "cartItemId": cartItemId,
            "catalogItemId": catalogItemId,
            "quantity": quantity,
            "unitPrice": unitPrice,
            "totalPrice": totalPrice,
            "currency": currency
        ]
    }
}
