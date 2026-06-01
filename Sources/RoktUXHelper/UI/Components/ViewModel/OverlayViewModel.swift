import Foundation
import DcuiSchema

@available(iOS 15, *)
class OverlayViewModel: Identifiable, Hashable, ScreenSizeAdaptive {
    let id: UUID = UUID()
    var children: [LayoutSchemaViewModel]?
    let allowBackdropToClose: Bool?
    let defaultStyle: [OverlayStyles]?
    let wrapperStyle: [OverlayWrapperStyles]?
    weak var eventService: EventServicing?
    weak var layoutState: (any LayoutStateRepresenting)?
    var imageLoader: RoktUXImageLoader? {
        layoutState?.imageLoader
    }

    init(children: [LayoutSchemaViewModel]?,
         allowBackdropToClose: Bool?,
         defaultStyle: [OverlayStyles]?,
         wrapperStyle: [OverlayWrapperStyles]?,
         eventService: EventServicing?,
         layoutState: (any LayoutStateRepresenting)?) {
        self.children = children
        self.allowBackdropToClose = allowBackdropToClose
        self.defaultStyle = defaultStyle
        self.wrapperStyle = wrapperStyle
        self.eventService = eventService
        self.layoutState = layoutState
    }
}
