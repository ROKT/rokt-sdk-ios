import Foundation

public struct RoktUXSlot: Codable {
    public let instanceGuid: String
    public let offer: RoktUXOffer?
    public let slotJWTToken: String

    enum CodingKeys: String, CodingKey {
        case instanceGuid
        case offer
        case slotJWTToken = "token"
    }
}
