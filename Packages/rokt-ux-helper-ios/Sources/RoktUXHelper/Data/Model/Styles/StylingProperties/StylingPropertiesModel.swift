import Foundation
import DcuiSchema

@available(iOS 13, *)
class StylingPropertiesModel: Decodable, Hashable {
    let container: ContainerStylingProperties?
    let background: BackgroundStylingProperties?
    let dimension: DimensionStylingProperties?
    let flexChild: FlexChildStylingProperties?
    let spacing: SpacingStylingProperties?
    let border: BorderStylingProperties?

    enum CodingKeys: String, CodingKey {
        case container
        case background
        case dimension
        case flexChild
        case spacing
        case border
    }

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        container = try values.decodeIfPresent(ContainerStylingProperties.self, forKey: .container)
        background = try values.decodeIfPresent(BackgroundStylingProperties.self, forKey: .background)
        dimension = try values.decodeIfPresent(DimensionStylingProperties.self, forKey: .dimension)
        flexChild = try values.decodeIfPresent(FlexChildStylingProperties.self, forKey: .flexChild)
        spacing = try values.decodeIfPresent(SpacingStylingProperties.self, forKey: .spacing)
        border = try values.decodeIfPresent(BorderStylingProperties.self, forKey: .border)
    }

    init(container: ContainerStylingProperties?,
         background: BackgroundStylingProperties?,
         dimension: DimensionStylingProperties?,
         flexChild: FlexChildStylingProperties?,
         spacing: SpacingStylingProperties?,
         border: BorderStylingProperties?) {
        self.container = container
        self.background = background
        self.dimension = dimension
        self.flexChild = flexChild
        self.spacing = spacing
        self.border = border
    }
}

@available(iOS 13, *)
extension StylingPropertiesModel: SpacingStyleable {}

extension Hashable where Self: AnyObject {
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

extension Equatable where Self: AnyObject {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs === rhs
    }
}
