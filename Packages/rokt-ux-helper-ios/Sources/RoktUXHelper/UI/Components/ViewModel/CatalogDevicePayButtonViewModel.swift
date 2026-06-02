import DcuiSchema
import Foundation
import SwiftUI

class CatalogDevicePayButtonViewModel: Identifiable, Hashable, ScreenSizeAdaptive, ObservableObject {
    let id: UUID = UUID()
    let catalogItem: CatalogItem
    var children: [LayoutSchemaViewModel]?
    var provider: PaymentProvider
    weak var eventService: EventDiagnosticServicing?
    weak var layoutState: (any LayoutStateRepresenting)?
    var imageLoader: RoktUXImageLoader? {
        layoutState?.imageLoader
    }

    let defaultStyle: [CatalogDevicePayButtonStyles]?
    let pressedStyle: [CatalogDevicePayButtonStyles]?
    let hoveredStyle: [CatalogDevicePayButtonStyles]?
    let disabledStyle: [CatalogDevicePayButtonStyles]?
    let validatorTriggerConfig: ValidationTriggerConfig?
    let transactionData: TransactionData?
    let customStateKey = CustomStateIdentifiable.Keys.paymentResult.rawValue
    var position: Int?

    @Published var isProcessing: Bool = false

    init(
        catalogItem: CatalogItem,
        children: [LayoutSchemaViewModel]?,
        provider: PaymentProvider,
        layoutState: (any LayoutStateRepresenting)?,
        eventService: EventDiagnosticServicing?,
        defaultStyle: [CatalogDevicePayButtonStyles]?,
        pressedStyle: [CatalogDevicePayButtonStyles]?,
        hoveredStyle: [CatalogDevicePayButtonStyles]?,
        disabledStyle: [CatalogDevicePayButtonStyles]?,
        validatorTriggerConfig: ValidationTriggerConfig?,
        transactionData: TransactionData? = nil
    ) {
        self.catalogItem = catalogItem
        self.children = children
        self.provider = provider
        self.defaultStyle = defaultStyle
        self.pressedStyle = pressedStyle
        self.hoveredStyle = hoveredStyle
        self.disabledStyle = disabledStyle
        self.layoutState = layoutState
        self.eventService = eventService
        self.validatorTriggerConfig = validatorTriggerConfig
        self.transactionData = transactionData
    }

    func handleTap() {
        guard !isProcessing else { return }

        guard shouldProceedAfterValidation() else {
            eventService?.cartItemUserInteraction(
                itemId: catalogItem.catalogItemId,
                action: UserInteraction.ValidationTriggerFailed,
                context: UserInteractionContext.CustomStateValidationTriggerButton
            )
            return
        }

        guard let eventService else { return }
        isProcessing = true
        eventService.cartItemDevicePay(
            catalogItem: catalogItem,
            paymentProvider: provider,
            transactionData: transactionData,
            completion: { [weak self] status in
                guard let self else { return }
                self.handleDevicePayCompletion(status: status)
            }
        )
    }

    private func handleDevicePayCompletion(status: DevicePayStatus) {
        DispatchQueue.main.async { [weak self] in
            self?.isProcessing = false
        }
        switch status {
        case .success:
            setLayoutVariantCustomState(key: customStateKey, value: 1)
        case .failure, .retry:
            setLayoutVariantCustomState(key: customStateKey, value: -1)
        case .pendingConfirmation(let catalogRuntimeData):
            // Publish runtime data first so reactive text resolution sees the values when the
            // confirmation subtree mounts on the devicePayState=1 transition.
            setCatalogRuntimeData(catalogRuntimeData)
            setLayoutVariantCustomState(
                key: CustomStateIdentifiable.Keys.devicePayState.rawValue,
                value: 1
            )
        }
    }

    private func setLayoutVariantCustomState(key: String, value: Int) {
        guard let layoutState,
              let binding = layoutState.items[LayoutState.customStateMap] as? Binding<RoktUXCustomStateMap?>
        else { return }

        let identifier = CustomStateIdentifiable(position: position, key: key)

        DispatchQueue.main.async {
            var map = binding.wrappedValue ?? [:]
            map[identifier] = value
            binding.wrappedValue = map
            layoutState.publishStateChange()
        }
    }

    private func setCatalogRuntimeData(_ catalogRuntimeData: [String: String]) {
        guard let layoutState else { return }
        DispatchQueue.main.async {
            var newItems = layoutState.items
            newItems[LayoutState.catalogRuntimeDataKey] = catalogRuntimeData
            // Setter on `items` re-publishes through `itemsPublisher`, triggering reactive
            // catalog-runtime resolution in BasicTextViewModel / RichTextViewModel.
            layoutState.items = newItems
        }
    }

    private func shouldProceedAfterValidation() -> Bool {
        guard let triggerConfig = validatorTriggerConfig,
              !triggerConfig.validatorFieldKeys.isEmpty,
              let coordinator = layoutState?.validationCoordinator else {
            return true
        }
        return coordinator.validate(fields: triggerConfig.validatorFieldKeys)
    }

    static func == (lhs: CatalogDevicePayButtonViewModel, rhs: CatalogDevicePayButtonViewModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
