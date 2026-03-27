import Foundation

struct UpsellItem: Decodable {
    let cartItemId: String
    let catalogItemId: String
    let quantity: Decimal
    let unitPrice: Decimal
    let totalPrice: Decimal
    let currency: String

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
