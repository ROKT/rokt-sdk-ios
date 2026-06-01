import Foundation

public struct RoktUXPlacementContext: Codable {
    public let roktTagId: String
    public let pageInstanceGuid: String
    public let placementContextJWTToken: String

    enum CodingKeys: String, CodingKey {
        case roktTagId
        case pageInstanceGuid
        case placementContextJWTToken = "token"
    }
}
