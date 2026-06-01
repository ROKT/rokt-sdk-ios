import Foundation

struct CatalogItemGroup: Codable {
    let groupId: String
    let catalogItemIds: [String]
    let attributes: [CatalogItemGroupAttribute]?
    let metadata: [String: String]?
}

struct CatalogItemGroupAttribute: Codable {
    let attributeId: String
    let label: String?
    let options: [CatalogItemGroupOption]?
    let metadata: [String: String]?
}

struct CatalogItemGroupOption: Codable {
    let label: String?
    let catalogItemIds: [String]?
    let metadata: [String: String]?
}
