import Foundation

@available(iOS 13, *)
/// Each plugin object has a single key, plugin. The consumable data, `PluginModel`, is its value
struct PluginWrapperModel: Decodable {
    let plugin: PluginModel
}

@available(iOS 13, *)
struct PluginModel: Decodable {
    let id: String
    let name: String?
    let config: PluginConfig
    let targetElementSelector: String?

    var configJWTToken: String? { config.jwtToken }
}

@available(iOS 13, *)
struct PluginConfig: Decodable {
    let instanceGuid: String?
    let slots: [SlotModel]?
    let outerLayoutSchema: OuterLayoutSchemaNetworkModel?
    let jwtToken: String

    enum CodingKeys: String, CodingKey {
        case instanceGuid
        case slots
        case outerLayoutSchema
        case jwtToken = "token"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        instanceGuid = try container.decodeIfPresent(String.self, forKey: .instanceGuid)

        slots = try container.decodeIfPresent([SlotModel].self, forKey: .slots)

        let outerLayoutSchemaString = try container.decode(String.self, forKey: .outerLayoutSchema)
        let outerLayoutSchemaData = outerLayoutSchemaString.data(using: .utf8)
        // Validate the josn to OuterLayoutSchemaModel
        _ = try JSONDecoder().decode(OuterLayoutSchemaValidationModel.self, from: outerLayoutSchemaData ?? Data())
        // Decode it as generic LayoutSchemaModel
        outerLayoutSchema = try JSONDecoder().decode(OuterLayoutSchemaNetworkModel.self, from: outerLayoutSchemaData ?? Data())

        jwtToken = try container.decode(String.self, forKey: .jwtToken)
    }
}
