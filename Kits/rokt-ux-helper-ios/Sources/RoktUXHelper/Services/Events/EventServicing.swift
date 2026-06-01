import Foundation
import DcuiSchema

protocol EventServicing: AnyObject {
    var dismissOption: LayoutDismissOptions? { get set }
    func sendSignalLoadStartEvent()
    func sendEventsOnTransformerSuccess()
    func sendSignalActivationEvent()
    func sendEventsOnLoad()
    func sendSlotImpressionEvent(instanceGuid: String, jwtToken: String)
    func sendSignalViewedEvent(instanceGuid: String, jwtToken: String)
    func sendSignalResponseEvent(instanceGuid: String, jwtToken: String, isPositive: Bool)
    func sendGatedSignalResponseEvent(instanceGuid: String, jwtToken: String, isPositive: Bool)
    func sendDismissalEvent()
    func openURL(url: URL, type: RoktUXOpenURLType, completionHandler: @escaping () -> Void)
    func cartItemInstantPurchase(catalogItem: CatalogItem)
    func cartItemInstantPurchaseSuccess(itemId: String)
    func cartItemUserInteraction(itemId: String, action: UserInteraction, context: UserInteractionContext)
    func cartItemInstantPurchaseFailure(itemId: String)
    func cartItemDevicePay(
        catalogItem: CatalogItem,
        paymentProvider: PaymentProvider,
        transactionData: TransactionData?,
        completion: @escaping (_ status: DevicePayStatus) -> Void
    )
    func cartItemDevicePaySuccess(itemId: String)
    func cartItemDevicePayFailure(itemId: String)
    func cartItemDevicePayPendingConfirmation(itemId: String, catalogRuntimeData: [String: String])
    func cartItemForwardPayment(
        catalogItem: CatalogItem,
        transactionData: TransactionData?,
        completion: @escaping (_ status: ForwardPaymentStatus) -> Void
    )
    func cartItemForwardPaymentSuccess(itemId: String)
    func cartItemForwardPaymentFailure(itemId: String, failureReason: String?)
}
