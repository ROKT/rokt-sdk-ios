import Foundation

struct SlotModel: Decodable {
    let instanceGuid: String?

    // contains BNF placeholder Strings
    // has properties or nested entities with properties that provide the actual value of BNF placeholder Strings
    let offer: OfferModel?

    let layoutVariant: LayoutVariantModel?

    let jwtToken: String

    enum CodingKeys: String, CodingKey {
        case instanceGuid
        case offer
        case layoutVariant
        case jwtToken = "token"
    }
}
