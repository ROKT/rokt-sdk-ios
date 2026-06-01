import Foundation
import DcuiSchema

@available(iOS 15, *)
class BottomSheetViewModel: Identifiable, Hashable, ScreenSizeAdaptive {
    let id: UUID = UUID()
    var children: [LayoutSchemaViewModel]?
    let allowBackdropToClose: Bool?
    let defaultStyle: [BottomSheetStyles]?
    weak var eventService: EventServicing?
    weak var layoutState: (any LayoutStateRepresenting)?
    var imageLoader: RoktUXImageLoader? {
        layoutState?.imageLoader
    }

    init(children: [LayoutSchemaViewModel]?,
         allowBackdropToClose: Bool?,
         defaultStyle: [BottomSheetStyles]?,
         eventService: EventServicing?,
         layoutState: (any LayoutStateRepresenting)?) {
        self.children = children
        self.allowBackdropToClose = allowBackdropToClose
        self.defaultStyle = defaultStyle
        self.eventService = eventService
        self.layoutState = layoutState
    }
}
