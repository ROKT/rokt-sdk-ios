import Foundation
import DcuiSchema

@available(iOS 15, *)
class ProgressControlViewModel: Identifiable, Hashable, ScreenSizeAdaptive {
    let id: UUID = UUID()
    var children: [LayoutSchemaViewModel]?
    let defaultStyle: [ProgressControlStyle]?
    let pressedStyle: [ProgressControlStyle]?
    let hoveredStyle: [ProgressControlStyle]?
    let disabledStyle: [ProgressControlStyle]?
    let direction: ProgressionDirection
    weak var layoutState: (any LayoutStateRepresenting)?
    var imageLoader: RoktUXImageLoader? {
        layoutState?.imageLoader
    }

    init(children: [LayoutSchemaViewModel]?,
         defaultStyle: [ProgressControlStyle]?,
         pressedStyle: [ProgressControlStyle]?,
         hoveredStyle: [ProgressControlStyle]?,
         disabledStyle: [ProgressControlStyle]?,
         direction: ProgressionDirection,
         layoutState: (any LayoutStateRepresenting)?) {
        self.children = children
        self.defaultStyle = defaultStyle
        self.pressedStyle = pressedStyle
        self.hoveredStyle = hoveredStyle
        self.disabledStyle = disabledStyle
        self.direction = direction
        self.layoutState = layoutState
    }
}
