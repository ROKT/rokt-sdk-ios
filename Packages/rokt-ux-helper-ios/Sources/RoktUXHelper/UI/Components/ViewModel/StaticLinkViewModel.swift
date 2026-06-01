import Foundation
import DcuiSchema

@available(iOS 15, *)
class StaticLinkViewModel: Identifiable, Hashable, ScreenSizeAdaptive {

    private let src: String
    private let open: LinkOpenTarget
    private weak var eventService: EventDiagnosticServicing?
    private(set) var children: [LayoutSchemaViewModel]?
    let id: UUID = UUID()
    let defaultStyle: [StaticLinkStyles]?
    let pressedStyle: [StaticLinkStyles]?
    let hoveredStyle: [StaticLinkStyles]?
    let disabledStyle: [StaticLinkStyles]?
    weak var layoutState: (any LayoutStateRepresenting)?
    var imageLoader: RoktUXImageLoader? {
        layoutState?.imageLoader
    }

    init(children: [LayoutSchemaViewModel]?,
         src: String,
         open: LinkOpenTarget,
         defaultStyle: [StaticLinkStyles]?,
         pressedStyle: [StaticLinkStyles]?,
         hoveredStyle: [StaticLinkStyles]?,
         disabledStyle: [StaticLinkStyles]?,
         layoutState: (any LayoutStateRepresenting)?,
         eventService: EventDiagnosticServicing?) {
        self.children = children
        self.src = src
        self.open = open
        self.defaultStyle = defaultStyle
        self.pressedStyle = pressedStyle
        self.hoveredStyle = hoveredStyle
        self.disabledStyle = disabledStyle
        self.layoutState = layoutState
        self.eventService = eventService
    }

    func handleLink() {
        guard let url = URL(string: src) else {
            eventService?.sendDiagnostics(message: kUrlErrorCode,
                                          callStack: src)
            return
        }
        eventService?.openURL(url: url, type: .init(open), completionHandler: {})
    }
}
