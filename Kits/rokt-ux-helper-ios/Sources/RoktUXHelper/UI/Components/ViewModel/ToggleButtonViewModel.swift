import Foundation
import DcuiSchema

@available(iOS 15, *)
class ToggleButtonViewModel: Identifiable, Hashable, ScreenSizeAdaptive {
    let id: UUID = UUID()
    var children: [LayoutSchemaViewModel]?
    let customStateKey: String
    let defaultStyle: [ToggleButtonStateTriggerStyle]?
    let pressedStyle: [ToggleButtonStateTriggerStyle]?
    let hoveredStyle: [ToggleButtonStateTriggerStyle]?
    let disabledStyle: [ToggleButtonStateTriggerStyle]?
    weak var layoutState: (any LayoutStateRepresenting)?
    var imageLoader: RoktUXImageLoader? {
        layoutState?.imageLoader
    }

    init(children: [LayoutSchemaViewModel]?,
         customStateKey: String,
         defaultStyle: [ToggleButtonStateTriggerStyle]?,
         pressedStyle: [ToggleButtonStateTriggerStyle]?,
         hoveredStyle: [ToggleButtonStateTriggerStyle]?,
         disabledStyle: [ToggleButtonStateTriggerStyle]?,
         layoutState: (any LayoutStateRepresenting)?) {
        self.children = children
        self.customStateKey = customStateKey
        self.defaultStyle = defaultStyle
        self.pressedStyle = pressedStyle
        self.hoveredStyle = hoveredStyle
        self.disabledStyle = disabledStyle
        self.layoutState = layoutState
    }
}
