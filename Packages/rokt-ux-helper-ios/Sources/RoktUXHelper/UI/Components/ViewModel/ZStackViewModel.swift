import Foundation
import DcuiSchema

@available(iOS 15, *)
class ZStackViewModel: Identifiable, Hashable, ScreenSizeAdaptive {
    let id: UUID = UUID()
    var children: [LayoutSchemaViewModel]?
    let defaultStyle: [ZStackStyle]?
    let pressedStyle: [ZStackStyle]?
    let hoveredStyle: [ZStackStyle]?
    let disabledStyle: [ZStackStyle]?
    let accessibilityGrouped: Bool
    weak var layoutState: (any LayoutStateRepresenting)?
    var imageLoader: RoktUXImageLoader? {
        layoutState?.imageLoader
    }

    init(children: [LayoutSchemaViewModel]?,
         defaultStyle: [ZStackStyle]?,
         pressedStyle: [ZStackStyle]?,
         hoveredStyle: [ZStackStyle]?,
         disabledStyle: [ZStackStyle]?,
         accessibilityGrouped: Bool,
         layoutState: (any LayoutStateRepresenting)?) {
        self.children = children
        self.defaultStyle = defaultStyle
        self.pressedStyle = pressedStyle
        self.hoveredStyle = hoveredStyle
        self.disabledStyle = disabledStyle
        self.accessibilityGrouped = accessibilityGrouped
        self.layoutState = layoutState
    }
}
