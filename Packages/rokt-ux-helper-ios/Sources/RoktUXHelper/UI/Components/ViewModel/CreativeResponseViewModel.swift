import Foundation
import DcuiSchema

@available(iOS 15, *)
class CreativeResponseViewModel: Identifiable, Hashable, ScreenSizeAdaptive {
    let id: UUID = UUID()
    var children: [LayoutSchemaViewModel]?
    let responseKey: BNFNamespace.CreativeResponseKey
    let responseOptions: RoktUXResponseOption?
    let openLinks: LinkOpenTarget?
    weak var eventService: EventDiagnosticServicing?
    weak var layoutState: (any LayoutStateRepresenting)?
    var imageLoader: RoktUXImageLoader? {
        layoutState?.imageLoader
    }

    let defaultStyle: [CreativeResponseStyles]?
    let pressedStyle: [CreativeResponseStyles]?
    let hoveredStyle: [CreativeResponseStyles]?
    let disabledStyle: [CreativeResponseStyles]?

    init(children: [LayoutSchemaViewModel]?,
         responseKey: BNFNamespace.CreativeResponseKey,
         responseOptions: RoktUXResponseOption?,
         openLinks: LinkOpenTarget?,
         layoutState: (any LayoutStateRepresenting)?,
         eventService: EventDiagnosticServicing?,
         defaultStyle: [CreativeResponseStyles]?,
         pressedStyle: [CreativeResponseStyles]?,
         hoveredStyle: [CreativeResponseStyles]?,
         disabledStyle: [CreativeResponseStyles]?) {
        self.children = children
        self.responseKey = responseKey
        self.responseOptions = responseOptions
        self.defaultStyle = defaultStyle
        self.pressedStyle = pressedStyle
        self.hoveredStyle = hoveredStyle
        self.disabledStyle = disabledStyle
        self.openLinks = openLinks
        self.layoutState = layoutState
        self.eventService = eventService
    }

    func sendSignalResponseEvent() {
        guard let responseJWTToken = responseOptions?.responseJWTToken else { return }

        switch responseOptions?.signalType {
        case .signalGatedResponse:
            eventService?.sendGatedSignalResponseEvent(
                instanceGuid: responseOptions?.instanceGuid ?? "",
                jwtToken: responseJWTToken,
                isPositive: responseKey == .positive
            )
        case .signalResponse:
            eventService?.sendSignalResponseEvent(
                instanceGuid: responseOptions?.instanceGuid ?? "",
                jwtToken: responseJWTToken,
                isPositive: responseKey == .positive
            )
        default:
            break
        }
    }

    func getOfferUrl() -> URL? {
        guard let urlString = responseOptions?.url,
              responseOptions?.action == .url
        else { return nil }

        return URL(string: urlString)
    }

    func handleLink(url: URL) {
        eventService?.openURL(url: url, type: .init(openLinks, sessionId: (eventService as? EventService)?.sessionId),
                              completionHandler: { [weak self] in
            self?.goToNextOffer()
        })
    }

    func goToNextOffer() {
        layoutState?.actionCollection[.nextOffer](nil)
    }
}
