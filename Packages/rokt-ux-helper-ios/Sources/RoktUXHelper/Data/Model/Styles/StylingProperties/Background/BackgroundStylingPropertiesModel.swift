import Foundation
import DcuiSchema

@available(iOS 13, *)
struct BackgroundStylingPropertiesModel: Decodable, Hashable {
    let backgroundColor: ThemeColor?
    let backgroundImage: BackgroundImageStyleModel?
}
