import SwiftUI

@available(iOS 13, *)
struct HeightProperty: Decodable, Hashable {
    let dimensionType: HeightDimensionType?

    enum CodingKeys: String, CodingKey {
        case value
        case dimensionType = "type"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        let dimensionTypeRaw = try values.decodeIfPresent(String.self, forKey: .dimensionType)

        guard let dimensionTypeRaw else {
            throw CustomDecodingError.invalidKey(name: CodingKeys.dimensionType.rawValue)
        }

        switch dimensionTypeRaw.lowercased() {
        case HeightDimensionType.fixedRaw:
            let value = try values.decodeIfPresent(Float.self, forKey: .value)
            dimensionType = .fixed(value)
        case HeightDimensionType.percentageRaw:
            let value = try values.decodeIfPresent(Float.self, forKey: .value)
            dimensionType = .percentage(value)
        case HeightDimensionType.fitRaw:
            let value = try values.decodeIfPresent(HeightFitProperty.self, forKey: .value)
            dimensionType = .fit(value)
        default:
            throw CustomDecodingError.invalidKey(name: CodingKeys.value.rawValue)
        }
    }

    init(dimensionType: HeightDimensionType?) {
        self.dimensionType = dimensionType
    }

    var heightPercentage: Float? {
        if case .percentage(let heightPercentage) = dimensionType {
            return heightPercentage
        } else {
            return nil
        }
    }
}
