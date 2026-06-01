import Foundation
import DcuiSchema

@available(iOS 13, *)
struct OuterLayoutSchemaNetworkModel: Decodable {
    public let breakpoints: BreakPoint?
    public let layout: LayoutSchemaModel?
    public let settings: LayoutSettings?
}

@available(iOS 13, *)
struct OuterLayoutSchemaValidationModel: Decodable {
    let breakpoints: BreakPoint?
    let layout: OuterLayoutSchemaModel?
    let settings: LayoutSettings?
}
