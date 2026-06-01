import Foundation
import DcuiSchema

@available(iOS 15, *)
class ColumnViewModel: Identifiable, Hashable, ScreenSizeAdaptive {
    let id: UUID = UUID()
    var children: [LayoutSchemaViewModel]?
    let defaultStyle: [ColumnStyle]?
    let pressedStyle: [ColumnStyle]?
    let hoveredStyle: [ColumnStyle]?
    let disabledStyle: [ColumnStyle]?
    let accessibilityGrouped: Bool
    weak var layoutState: (any LayoutStateRepresenting)?

    var imageLoader: RoktUXImageLoader? {
        layoutState?.imageLoader
    }

    init(children: [LayoutSchemaViewModel]?,
         defaultStyle: [ColumnStyle]?,
         pressedStyle: [ColumnStyle]?,
         hoveredStyle: [ColumnStyle]?,
         disabledStyle: [ColumnStyle]?,
         accessibilityGrouped: Bool,
         layoutState: any LayoutStateRepresenting) {
        self.children = children
        self.defaultStyle = defaultStyle
        self.pressedStyle = pressedStyle
        self.hoveredStyle = hoveredStyle
        self.disabledStyle = disabledStyle
        self.accessibilityGrouped = accessibilityGrouped
        self.layoutState = layoutState
    }
}
