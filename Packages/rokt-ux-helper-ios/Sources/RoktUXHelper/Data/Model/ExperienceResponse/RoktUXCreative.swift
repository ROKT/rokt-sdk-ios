import Foundation

public struct RoktUXCreative: Codable {
    public let referralCreativeId: String
    public let instanceGuid: String
    public let copy: [String: String]
    public let responseOptions: [RoktUXResponseOption]?
    public let creativeJWTToken: String

    enum CodingKeys: String, CodingKey {
        case referralCreativeId
        case instanceGuid
        case copy
        case responseOptions
        case creativeJWTToken = "token"
    }
}
