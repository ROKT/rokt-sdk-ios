import Foundation

struct CatalogItem: Codable {
    let images: [String: CreativeImage]
    let catalogItemId: String
    let cartItemId: String
    let instanceGuid: String
    let title: String
    let description: String
    let price: Decimal?
    let priceFormatted: String?
    let originalPrice: Decimal?
    let originalPriceFormatted: String?
    let currency: String
    let signalType: String?
    let url: String?
    let minItemCount: Int?
    let maxItemCount: Int?
    let preSelectedQuantity: Int?
    let providerData: String
    let urlBehavior: String?
    let positiveResponseText: String
    let negativeResponseText: String
    let addOns: [String]?
    let copy: [String: String]?
    let inventoryStatus: String?
    let linkedProductId: String?
    let token: String
}
