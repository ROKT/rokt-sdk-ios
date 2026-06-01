import Foundation
import DcuiSchema

@available(iOS 15, *)
class DataImageViewModel: Hashable, Identifiable, ObservableObject, ScreenSizeAdaptive {
    let id: UUID = UUID()

    let image: CreativeImage?
    let defaultStyle: [DataImageStyles]?
    let pressedStyle: [DataImageStyles]?
    let hoveredStyle: [DataImageStyles]?
    let disabledStyle: [DataImageStyles]?
    weak var layoutState: (any LayoutStateRepresenting)?
    var imageLoader: RoktUXImageLoader? {
        layoutState?.imageLoader
    }

    init(image: CreativeImage?,
         defaultStyle: [DataImageStyles]?,
         pressedStyle: [DataImageStyles]?,
         hoveredStyle: [DataImageStyles]?,
         disabledStyle: [DataImageStyles]?,
         layoutState: (any LayoutStateRepresenting)?) {
        self.image = image
        self.defaultStyle = defaultStyle
        self.pressedStyle = pressedStyle
        self.hoveredStyle = hoveredStyle
        self.disabledStyle = disabledStyle
        self.layoutState = layoutState
    }
}
