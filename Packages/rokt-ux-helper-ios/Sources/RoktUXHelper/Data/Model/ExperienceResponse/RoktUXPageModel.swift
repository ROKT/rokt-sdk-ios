import Foundation
import DcuiSchema

public struct RoktUXPageModel {
    public let pageId: String?
    public let sessionId: String
    public let pageInstanceGuid: String
    public let layoutPlugins: [LayoutPlugin]?
    var startDate: Date = Date()
    var responseReceivedDate: Date = Date()
    let token: String
    let options: [SDKOption]?
}

public struct LayoutPlugin {
    let pluginInstanceGuid: String
    let breakpoints: BreakPoint?
    let settings: LayoutSettings?
    let layout: LayoutSchemaModel?
    let slots: [SlotModel]
    let targetElementSelector: String?
    let pluginConfigJWTToken: String
    public let pluginId: String
    let pluginName: String?
}

enum PlacementType: Codable, Hashable {
    case BottomSheet(BottomSheetType)
    case Overlay
    case unSupported
}

enum BottomSheetType: Codable, Hashable {
    case fixed
    case dynamic
}

public typealias BreakPoint = [String: Float]
