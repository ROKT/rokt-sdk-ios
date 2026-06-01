import Foundation
import SwiftUI
import DcuiSchema

@available(iOS 15, *)
class CatalogResponseButtonViewModel: Identifiable, Hashable, ScreenSizeAdaptive {
    private static let paymentResultKey = CustomStateIdentifiable.Keys.paymentResult.rawValue

    let id: UUID = UUID()
    let catalogItem: CatalogItem?
    var children: [LayoutSchemaViewModel]?
    weak var eventService: EventDiagnosticServicing?
    weak var layoutState: (any LayoutStateRepresenting)?
    var imageLoader: RoktUXImageLoader? {
        layoutState?.imageLoader
    }

    let defaultStyle: [CatalogResponseButtonStyles]?
    let pressedStyle: [CatalogResponseButtonStyles]?
    let hoveredStyle: [CatalogResponseButtonStyles]?
    let disabledStyle: [CatalogResponseButtonStyles]?

    let transactionData: TransactionData?

    var isPartnerManagedPurchase: Bool {
        transactionData?.isPartnerManagedPurchase ?? true
    }

    init(catalogItem: CatalogItem?,
         children: [LayoutSchemaViewModel]?,
         layoutState: (any LayoutStateRepresenting)?,
         eventService: EventDiagnosticServicing?,
         defaultStyle: [CatalogResponseButtonStyles]?,
         pressedStyle: [CatalogResponseButtonStyles]?,
         hoveredStyle: [CatalogResponseButtonStyles]?,
         disabledStyle: [CatalogResponseButtonStyles]?,
         transactionData: TransactionData? = nil) {
        self.catalogItem = catalogItem
        self.children = children
        self.defaultStyle = defaultStyle
        self.pressedStyle = pressedStyle
        self.hoveredStyle = hoveredStyle
        self.disabledStyle = disabledStyle
        self.layoutState = layoutState
        self.eventService = eventService
        self.transactionData = transactionData
    }

    func cartItemInstantPurchase(position: Int?) {
        guard let catalogItem else {
            sendCloseEvent()
            closeLayout()
            return
        }

        if isPartnerManagedPurchase {
            eventService?.cartItemInstantPurchase(catalogItem: catalogItem)
            sendCloseEvent()
            closeLayout()
        } else {
            eventService?.cartItemForwardPayment(
                catalogItem: catalogItem,
                transactionData: transactionData,
                completion: { [weak self] status in
                    self?.handleForwardPaymentCompletion(status: status, position: position)
                }
            )
        }
    }

    private func closeLayout() {
        layoutState?.actionCollection[.close](nil)
    }

    private func handleForwardPaymentCompletion(status: ForwardPaymentStatus, position: Int?) {
        let result: Int
        switch status {
        case .success:
            result = 1
        case .failure:
            result = -1
        }
        setPaymentResult(result, position: position)
    }

    private func setPaymentResult(_ value: Int, position: Int?) {
        guard let layoutState,
              let binding = layoutState.items[LayoutState.customStateMap] as? Binding<RoktUXCustomStateMap?>
        else { return }

        DispatchQueue.main.async {
            var map = binding.wrappedValue ?? [:]
            map[CustomStateIdentifiable(position: position, key: Self.paymentResultKey)] = value
            binding.wrappedValue = map
            layoutState.publishStateChange()
        }
    }

    private func sendCloseEvent() {
        eventService?.dismissOption = .defaultDismiss
        eventService?.sendDismissalEvent()
    }
}
