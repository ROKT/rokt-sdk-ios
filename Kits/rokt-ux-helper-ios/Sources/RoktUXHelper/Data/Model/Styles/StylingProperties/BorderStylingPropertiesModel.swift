import Foundation
import DcuiSchema

@available(iOS 13, *)
struct BorderStylingPropertiesModel: Decodable, Hashable {
    let borderRadius: Float?
    let borderColor: ThemeColor?
    let borderWidth: Float?
    let borderStyle: BorderStyle?
}
