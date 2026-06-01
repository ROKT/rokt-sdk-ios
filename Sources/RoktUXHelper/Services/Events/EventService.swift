import Foundation
import SwiftUI
import Combine
import DcuiSchema

enum LayoutDismissOptions {
    case closeButton, noMoreOffer, endMessage, collapsed, defaultDismiss, partnerTriggered, instantPurchaseDismiss
}

enum DevicePayStatus {
    case success
    case failure
    case retry
    /// Intermediate state emitted when the host SDK has fetched the cart breakdown
    /// (subtotal/tax/shipping/total + e.g. PayPal URL) and the UX should now display
    /// the confirmation screen before the user finalizes the purchase.
    case pendingConfirmation(catalogRuntimeData: [String: String])
}

enum ForwardPaymentStatus {
    case success
    case failure(reason: String?)
}

typealias EventDiagnosticServicing = EventServicing & DiagnosticServicing

@available(iOS 13.0, *)
class EventService: Hashable, EventDiagnosticServicing {
    let pageId: String?
    let pageInstanceGuid: String
    let sessionId: String
    let pluginInstanceGuid: String
    let pluginId: String
    let pluginName: String?
    let startDate: Date
    let pluginConfigJWTToken: String
    let useDiagnosticEvents: Bool
    let processor: EventProcessing
    let catalogItems: [CatalogItem]

    weak var uxEventDelegate: UXEventsDelegate?
    var responseReceivedDate: Date
    var isFirstPositiveEngagementSend = false
    var dismissOption: LayoutDismissOptions?

    private var devicePayCompletion: ((_ status: DevicePayStatus) -> Void)?
    private var forwardPaymentCompletion: ((_ status: ForwardPaymentStatus) -> Void)?

    init(pageId: String?,
         pageInstanceGuid: String,
         sessionId: String,
         pluginInstanceGuid: String,
         pluginId: String,
         pluginName: String?,
         startDate: Date,
         catalogItems: [CatalogItem] = [],
         uxEventDelegate: UXEventsDelegate,
         processor: EventProcessing,
         responseReceivedDate: Date,
         isFirstPositiveEngagementSend: Bool = false,
         pluginConfigJWTToken: String,
         dismissOption: LayoutDismissOptions? = nil,
         useDiagnosticEvents: Bool) {
        self.pageId = pageId
        self.pageInstanceGuid = pageInstanceGuid
        self.sessionId = sessionId
        self.pluginInstanceGuid = pluginInstanceGuid
        self.pluginId = pluginId
        self.pluginName = pluginName
        self.startDate = startDate
        self.uxEventDelegate = uxEventDelegate
        self.responseReceivedDate = responseReceivedDate
        self.isFirstPositiveEngagementSend = isFirstPositiveEngagementSend
        self.pluginConfigJWTToken = pluginConfigJWTToken
        self.dismissOption = dismissOption
        self.useDiagnosticEvents = useDiagnosticEvents
        self.processor = processor
        self.catalogItems = catalogItems
    }

    func sendSignalLoadStartEvent() {
        sendEvent(.SignalLoadStart, parentGuid: pluginInstanceGuid, jwtToken: pluginConfigJWTToken)
    }

    func sendEventsOnTransformerSuccess() {
        sendPlacementReadyEventCallback()
        sendSignalLoadCompleteEvent()
    }

    private func sendPlacementReadyEventCallback() {
        uxEventDelegate?.onPlacementReady(pluginId)
    }

    private func sendSignalLoadCompleteEvent() {
        sendEvent(.SignalLoadComplete, parentGuid: pluginInstanceGuid, jwtToken: pluginConfigJWTToken)
    }

    func sendSignalActivationEvent() {
        sendEvent(.SignalActivation, parentGuid: pluginInstanceGuid, jwtToken: pluginConfigJWTToken)
    }

    func sendEventsOnLoad() {
        sendPlacementInteractiveEventCallback()
        sendPluginImpressionEvent()
    }

    func sendSlotImpressionEvent(instanceGuid: String, jwtToken: String) {
        sendEvent(.SignalImpression, parentGuid: instanceGuid, jwtToken: jwtToken)
    }

    func sendSignalViewedEvent(instanceGuid: String, jwtToken: String) {
        sendEvent(.SignalViewed, parentGuid: instanceGuid, jwtToken: jwtToken)
    }

    func sendSignalResponseEvent(instanceGuid: String, jwtToken: String, isPositive: Bool) {
        sendEngagementEventCallback(isPositive: isPositive)
        sendEvent(
            .SignalResponse,
            parentGuid: instanceGuid,
            jwtToken: jwtToken
        )
    }
    func sendGatedSignalResponseEvent(instanceGuid: String, jwtToken: String, isPositive: Bool) {
        sendEngagementEventCallback(isPositive: isPositive)
        sendEvent(.SignalGatedResponse,
                  parentGuid: instanceGuid,
                  jwtToken: jwtToken)
    }

    func sendDismissalEvent() {
        forwardPaymentCompletion = nil
        sendDismissalEventCallback()
        switch dismissOption {
        case .noMoreOffer:
            sendDismissalNoMoreOfferEvent()
        case .closeButton:
            sendDismissalCloseEvent()
        case .endMessage:
            sendDismissalEndMessageEvent()
        case .collapsed:
            sendDismissalCollapsedEvent()
        case .partnerTriggered:
            sendDismissalPartnerTriggeredEvent()
        case .instantPurchaseDismiss:
            sendInstantPurchaseDissmissOfferEvent()
        default:
            sendDefaultDismissEvent()
        }
    }

    func sendEvent(
        _ eventType: RoktUXEventType,
        parentGuid: String,
        extraMetadata: [RoktEventNameValue] = [RoktEventNameValue](),
        eventData: [String: String] = [:],
        objectData: [String: String]? = nil,
        jwtToken: String
    ) {
        processor.handle(
            event: RoktEventRequest(
                sessionId: sessionId,
                eventType: eventType,
                parentGuid: parentGuid,
                extraMetadata: extraMetadata,
                eventData: eventData,
                objectData: objectData,
                pageInstanceGuid: pageInstanceGuid,
                jwtToken: jwtToken
            )
        )
    }

    func openURL(url: URL, type: RoktUXOpenURLType, completionHandler: @escaping () -> Void) {
        canOpenUrl(url)
        let id = UUID().uuidString
        uxEventDelegate?.openURL(url: url.absoluteString, id: id, layoutId: pluginId, type: type, onClose: { incomingId in
            if id == incomingId {
                completionHandler()
            }
        }, onError: { [weak self] incomingId, error in
            if id == incomingId {
                self?.sendDiagnostics(message: kWebViewErrorCode,
                                      callStack: error?.localizedDescription ?? kStaticPageError)
            }
        })
    }

    func cartItemInstantPurchase(catalogItem: CatalogItem) {
        sendCartItemEvent(eventType: .SignalCartItemInstantPurchaseInitiated, catalogItem: catalogItem)
        uxEventDelegate?.onCartItemInstantPurchase(pluginId, catalogItem: catalogItem)
    }

    func cartItemInstantPurchaseSuccess(itemId: String) {
        guard let catalogItem = catalogItems.first(where: { $0.catalogItemId == itemId }) else { return }
        sendCartItemEvent(eventType: .SignalCartItemInstantPurchase, catalogItem: catalogItem)
    }

    func cartItemInstantPurchaseFailure(itemId: String) {
        guard let catalogItem = catalogItems.first(where: { $0.catalogItemId == itemId }) else { return }
        sendCartItemEvent(eventType: .SignalCartItemInstantPurchaseFailure, catalogItem: catalogItem)
    }

    func cartItemUserInteraction(itemId: String, action: UserInteraction, context: UserInteractionContext) {
        guard let catalogItem = catalogItems.first(where: { $0.catalogItemId == itemId }) else { return }
        let objectData = [
            kAction: action.rawValue,
            kContext: context.rawValue
        ]
        sendCartItemEvent(eventType: .SignalUserInteraction, catalogItem: catalogItem, objectData: objectData)
    }

    func cartItemDevicePay(
        catalogItem: CatalogItem,
        paymentProvider: PaymentProvider,
        transactionData: TransactionData?,
        completion: @escaping (_ status: DevicePayStatus) -> Void
    ) {
        guard devicePayCompletion == nil else {
            sendDiagnostics(
                message: kDevicePayProcessingErrorCode,
                callStack: "Device pay already processing for layout \(pluginId); dropped \(catalogItem.catalogItemId)"
            )
            completion(.failure)
            return
        }

        let objectData = [
            kCatalogItemId: catalogItem.catalogItemId,
            kQuantity: "1"
        ]
        sendCartItemEvent(eventType: .SignalCartItemInstantPurchaseInitiated, catalogItem: catalogItem, objectData: objectData)
        uxEventDelegate?.onCartItemDevicePay(
            pluginId,
            catalogItem: catalogItem,
            paymentProvider: paymentProvider,
            transactionData: transactionData
        )

        self.devicePayCompletion = completion
    }

    func cartItemDevicePaySuccess(itemId: String) {
        guard let catalogItem = catalogItems.first(where: { $0.catalogItemId == itemId }) else { return }
        // For two-step flows that already transitioned to .pendingConfirmation,
        // devicePayCompletion was cleared by cartItemDevicePayPendingConfirmation and the
        // Step-2 SignalCartItemForwardPayment* signals own the terminal state. Skip emitting
        // SignalCartItemInstantPurchase here to avoid double-counting.
        guard let completion = devicePayCompletion else { return }
        sendCartItemEvent(eventType: .SignalCartItemInstantPurchase, catalogItem: catalogItem)
        completion(.success)
        devicePayCompletion = nil
    }

    func cartItemDevicePayFailure(itemId: String) {
        guard let catalogItem = catalogItems.first(where: { $0.catalogItemId == itemId }) else { return }
        // Symmetric guard with cartItemDevicePaySuccess — once the flow transitioned to
        // forward-payment Step-2, that branch owns the terminal failure signal.
        guard let completion = devicePayCompletion else { return }
        sendCartItemEvent(eventType: .SignalCartItemInstantPurchaseFailure, catalogItem: catalogItem)
        completion(.failure)
        devicePayCompletion = nil
    }

    /// Invoked when the host SDK has fetched the order breakdown from
    /// `/v1/cart/initialize-purchase` (or equivalent) and wants the UX to display the
    /// confirmation screen. Resolves the stored `devicePayCompletion` with the breakdown
    /// payload so the button view model can publish it to the layout. No new Rokt platform
    /// signal is emitted here — `SignalCartItemInstantPurchaseInitiated` was already sent
    /// when the user tapped the device-pay button.
    func cartItemDevicePayPendingConfirmation(itemId: String, catalogRuntimeData: [String: String]) {
        guard catalogItems.contains(where: { $0.catalogItemId == itemId }) else { return }
        devicePayCompletion?(.pendingConfirmation(catalogRuntimeData: catalogRuntimeData))
        devicePayCompletion = nil
    }

    func cartItemForwardPayment(
        catalogItem: CatalogItem,
        transactionData: TransactionData?,
        completion: @escaping (_ status: ForwardPaymentStatus) -> Void
    ) {
        guard forwardPaymentCompletion == nil else {
            sendDiagnostics(
                message: kForwardPaymentProcessingErrorCode,
                callStack: "Forward payment already processing for layout \(pluginId); dropped \(catalogItem.catalogItemId)"
            )
            return
        }

        self.forwardPaymentCompletion = completion

        sendCartItemEvent(eventType: .SignalCartItemInstantPurchaseInitiated, catalogItem: catalogItem)
        uxEventDelegate?.onCartItemForwardPayment(
            pluginId,
            catalogItem: catalogItem,
            transactionData: transactionData
        )
    }

    func cartItemForwardPaymentSuccess(itemId: String) {
        guard catalogItems.contains(where: { $0.catalogItemId == itemId }) else {
            sendDiagnostics(
                message: kForwardPaymentProcessingErrorCode,
                callStack: "Forward payment success for unknown itemId \(itemId) on layout \(pluginId)"
            )
            forwardPaymentCompletion?(.failure(reason: "Unknown catalog item: \(itemId)"))
            forwardPaymentCompletion = nil
            return
        }

        forwardPaymentCompletion?(.success)
        forwardPaymentCompletion = nil
    }

    func cartItemForwardPaymentFailure(itemId: String, failureReason: String?) {
        guard catalogItems.contains(where: { $0.catalogItemId == itemId }) else {
            sendDiagnostics(
                message: kForwardPaymentProcessingErrorCode,
                callStack: "Forward payment failure for unknown itemId \(itemId) on layout \(pluginId)"
            )
            forwardPaymentCompletion?(.failure(reason: failureReason ?? "Unknown catalog item: \(itemId)"))
            forwardPaymentCompletion = nil
            return
        }

        forwardPaymentCompletion?(.failure(reason: failureReason))
        forwardPaymentCompletion = nil
    }

    private func sendCartItemEvent(eventType: RoktUXEventType, catalogItem: CatalogItem, objectData: [String: String]? = nil) {
        sendEvent(
            eventType,
            parentGuid: catalogItem.instanceGuid,
            objectData: objectData,
            jwtToken: catalogItem.token
        )
    }

    private func canOpenUrl(_ url: URL) {
        if !UIApplication.shared.canOpenURL(url) {
            sendDiagnostics(message: kUrlErrorCode,
                            callStack: url.absoluteString)
        }
    }

    private func sendPlacementInteractiveEventCallback() {
        uxEventDelegate?.onPlacementInteractive(pluginId)
    }

    private func sendPluginImpressionEvent() {
        var metaData = [
            RoktEventNameValue(name: BE_PAGE_SIGNAL_LOAD,
                               value: EventDateFormatter.getDateString(startDate)),
            RoktEventNameValue(name: BE_PAGE_RENDER_ENGINE,
                               value: BE_RENDER_ENGINE_LAYOUTS),
            RoktEventNameValue(name: BE_PAGE_SIGNAL_COMPLETE,
                               value: EventDateFormatter.getDateString(responseReceivedDate)),
            RoktEventNameValue(name: BE_TIMINGS_EVENT_TIME_KEY,
                               value: EventDateFormatter.getDateString(DateHandler.currentDate())),
            RoktEventNameValue(name: BE_HEADER_PAGE_INSTANCE_GUID_KEY,
                               value: pageInstanceGuid),
            RoktEventNameValue(name: BE_TIMINGS_PLUGIN_ID_KEY,
                               value: pluginId)
        ]
        pageId.map {
            metaData.append(
                RoktEventNameValue(name: BE_VIEW_NAME_KEY, value: $0)
            )
        }
        pluginName.map {
            metaData.append(
                RoktEventNameValue(name: BE_TIMINGS_PLUGIN_NAME_KEY,
                                   value: $0)
            )
        }
        sendEvent(.SignalImpression,
                  parentGuid: pluginInstanceGuid,
                  extraMetadata: metaData,
                  jwtToken: pluginConfigJWTToken)
    }

    private func sendDismissalEndMessageEvent() {
        sendEvent(.SignalDismissal, parentGuid: pluginInstanceGuid,
                  extraMetadata: [RoktEventNameValue(name: kInitiator, value: kEndMessage)],
                  jwtToken: pluginConfigJWTToken)
    }

    private func sendDismissalCollapsedEvent() {
        sendEvent(.SignalDismissal, parentGuid: pluginInstanceGuid,
                  extraMetadata: [RoktEventNameValue(name: kInitiator, value: kCollapsed)],
                  jwtToken: pluginConfigJWTToken)
    }

    private func sendDismissalCloseEvent() {
        sendEvent(.SignalDismissal, parentGuid: pluginInstanceGuid,
                  extraMetadata: [RoktEventNameValue(name: kInitiator, value: kCloseButton)],
                  jwtToken: pluginConfigJWTToken)
    }
    private func sendDismissalPartnerTriggeredEvent() {
        sendEvent(.SignalDismissal, parentGuid: pluginInstanceGuid,
                  extraMetadata: [RoktEventNameValue(name: kInitiator, value: kPartnerTriggered)],
                  jwtToken: pluginConfigJWTToken)
    }

    private func sendInstantPurchaseDissmissOfferEvent() {
        sendEvent(.SignalInstantPurchaseDismissal, parentGuid: pluginInstanceGuid,
                  extraMetadata: [RoktEventNameValue(name: kInitiator, value: kInstantPurchaseDismiss)],
                  jwtToken: pluginConfigJWTToken)
    }

    private func sendDismissalNoMoreOfferEvent() {
        sendEvent(.SignalDismissal, parentGuid: pluginInstanceGuid,
                  extraMetadata: [RoktEventNameValue(name: kInitiator, value: kNoMoreOfferToShow)],
                  jwtToken: pluginConfigJWTToken)
    }

    private func sendDefaultDismissEvent() {
        sendEvent(.SignalDismissal, parentGuid: pluginInstanceGuid,
                  extraMetadata: [RoktEventNameValue(name: kInitiator, value: kDismissed)],
                  jwtToken: pluginConfigJWTToken)
    }

    private func sendEngagementEventCallback(isPositive: Bool) {
        uxEventDelegate?.onOfferEngagement(pluginId)

        if isPositive {
            uxEventDelegate?.onPositiveEngagement(pluginId)

            if !isFirstPositiveEngagementSend {
                uxEventDelegate?.onFirstPositiveEngagement(
                    sessionId: sessionId,
                    pluginInstanceGuid: pluginInstanceGuid,
                    jwtToken: pluginConfigJWTToken,
                    layoutId: pluginId
                )
                isFirstPositiveEngagementSend = true
            }
        }
    }

    private func sendDismissalEventCallback() {
        switch dismissOption {
        case .noMoreOffer, .endMessage, .collapsed:
            uxEventDelegate?.onPlacementCompleted(pluginId)
        case .closeButton, .partnerTriggered, .instantPurchaseDismiss:
            uxEventDelegate?.onPlacementClosed(pluginId)
        default:
            uxEventDelegate?.onPlacementClosed(pluginId)
        }
    }
}

class DateHandler {
    static var customDate: Date?

    static func currentDate() -> Date {
        return self.customDate ?? Date()
    }
}

class EventDateFormatter {

    static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: kBaseLocale)
        dateFormatter.dateFormat = kEventTimeStamp
        dateFormatter.timeZone = TimeZone(abbreviation: kUTCTimeStamp)
        return dateFormatter
    }()

    static func getDateString(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}
