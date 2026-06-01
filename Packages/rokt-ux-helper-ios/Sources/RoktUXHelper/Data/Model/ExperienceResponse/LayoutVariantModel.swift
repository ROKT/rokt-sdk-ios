import Foundation
import DcuiSchema

struct LayoutVariantModel: Decodable {
    let layoutVariantSchema: LayoutSchemaModel?
    let moduleName: String?

    enum CodingKeys: String, CodingKey {
        case layoutVariantSchema
        case moduleName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        moduleName = try container.decode(String.self, forKey: .moduleName)

        let layoutVariantSchemaString = try container.decode(String.self, forKey: .layoutVariantSchema)
        if layoutVariantSchemaString.isEmpty {
            layoutVariantSchema = nil
        } else {
            let layoutVariantSchemaData = layoutVariantSchemaString.data(using: .utf8)
            // Validate the json to be LayoutVariantChildren
            _ = try JSONDecoder().decode(LayoutVariantChildren.self,
                                         from: layoutVariantSchemaData ?? Data())
            // Decode it as generic LayoutSchemaModel
            layoutVariantSchema = try JSONDecoder().decode(LayoutSchemaModel.self,
                                                           from: layoutVariantSchemaData ?? Data())
        }
    }

    init(layoutVariantSchema: LayoutSchemaModel,
         moduleName: String?) {
        self.layoutVariantSchema = layoutVariantSchema
        self.moduleName = moduleName
    }
}
