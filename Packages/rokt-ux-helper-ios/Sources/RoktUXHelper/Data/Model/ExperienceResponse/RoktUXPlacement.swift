import Foundation

public struct RoktUXPlacement: Codable {
    public let id: String
    public let targetElementSelector: String
    public let offerLayoutCode: String
    public let placementLayoutCode: RoktUXPlacementLayoutCode?
    public let placementConfigurables: [String: String]?
    public let instanceGuid: String
    public let slots: [RoktUXSlot]?
    public let placementsJWTToken: String

    enum CodingKeys: String, CodingKey {
        case id
        case targetElementSelector
        case offerLayoutCode
        case placementLayoutCode
        case placementConfigurables
        case instanceGuid
        case slots
        case placementsJWTToken = "token"
    }
}
