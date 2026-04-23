import Foundation
import UIKit
import AppTrackingTransparency
internal import RoktUXHelper

class RoktInternalImplementation {
    private static let initDiagnosticCode = "[INIT]"
    private static let executeDiagnosticCode = "[EXECUTE]"
    private static let trackingConsentDiagnosticCode = "[TRACKINGCONSENT]"
    private static let notInitializedDiagnosticCode = "[NOT_INITIALIZED]"
    private static let cacheHitDiagnosticCode = "[CACHE_HIT]"
    private static let cacheHitMessage = "Cache hit for view - %@"
    private static let initFailedError = "INIT_FAILED"
    private static let fontFailedError = "FONT_FAILED"
    private static let defaultRoktInitEvent = "DEFAULT_ROKT_INIT_EVENT"
    private static let trackingConsentError = "tracking consent not authorised"
    private static let cacheDurationKey = "cacheDuration"
    private static let cacheAttributesKey = "cacheAttributeKeys"
    static let missingForwardPaymentPriceReason = "Missing price on forward-payment event"
    static let unknownForwardPaymentFailureReason = "Unknown failure reason"
    static let defaultTimeout: Double = 9000
    static let defaultFontTimeout: Double = 30 // second
    static let defaultDelay: Double = 1000

    private var fontLoadObservers: [NSObjectProtocol] = []

    var roktTagId: String?
    let sessionManager: SessionManager
    var attributes = [String: String]()
    var isInitialized = false
    var isInitFailedForFont = false
    private(set) var frameworkType: RoktFrameworkType = .iOS
    var processedEvents: PlatformEventProcessor?
    var fontDiagnostics = FontDiagnosticsViewModel()
    // Feature flags
    var initFeatureFlags: InitFeatureFlags = InitFeatureFlags(roktTrackingStatus: true,
                                                              shouldLogFontHappyPath: false,
                                                              shouldUseFontRegisterWithUrl: false,
                                                              featureFlags: [:])
    var processedTimingsRequests: TimingsRequestProcessor?

    private var stateManager: StateBagManaging = StateBagManager()
    private var clientTimeoutMilliseconds: Double = RoktInternalImplementation.defaultTimeout
    private var defaultLaunchDelayMilliseconds: Double = RoktInternalImplementation.defaultDelay
    private var loadingFonts = false
    private var pendingPayload: ExecutePayload?
    private var isExecuting = false
    private var placements: [String: RoktEmbeddedView]?

    // Caching is disabled by default when no CacheConfig is provided to the Builder.
    var roktConfig: RoktConfig = RoktConfig.Builder().build()

    private var linkHandler: LinkHandler = .init()
    var sentEventHashes: ThreadSafeSet<String> = .init()

    // store callback for partner event integration
    private var roktEvent: ((RoktEvent) -> Void)?
    private var roktEventMap: [String: ((RoktEvent) -> Void)?] = [:]

    // debounce work item for EmbeddedSizeChanged
    private var sizeChangeWorkItem: DispatchWorkItem?
    private let sizeChangeDebounceInterval: TimeInterval = 0.1

    // to hold RoktLayout for SwiftUI integration
    private var _swiftUiExecuteLayout: Any?

    private var swiftUiExecuteLayout: LayoutLoader? {
        return _swiftUiExecuteLayout as? LayoutLoader
    }

    // Payment orchestrator for Shoppable Ads
    private lazy var paymentOrchestrator = PaymentOrchestrator()

    var isPaymentExtensionRegistered: Bool { paymentOrchestrator.hasRegisteredExtension }

    func close() {
        guard let window = UIApplication.shared.windows.filter({$0.isKeyWindow}).first,
              let rootViewController = window.rootViewController
        else {
            return
        }

        if #available(iOS 15.0, *),
           let roktVC = rootViewController.presentedViewController as? RoktUXSwiftUIViewController {
            roktVC.closeModal()
            // close modal
        }
    }

    /// Rokt private initializer. Only available for the singleton object `shared`
    init() {
        let managedSessionObjects = [RealTimeEventManager.shared]
        sessionManager = SessionManager(managedSessions: managedSessionObjects)
        NetworkingHelper.updateTimeout(timeout: clientTimeoutMilliseconds/1000)
    }

    // Loading fonts notification observer selector
    private func startedLoadingFonts(notification: Notification) {
        loadingFonts = true
    }

    // Finished loading fonts notification observer selector
    private func finishedLoadingFonts(notification: Notification) {
        loadingFonts = false
        processedTimingsRequests?.setInitEndTime()

        if let page = pendingPayload {
            showNow(payload: page)
        }
    }

    func purchaseFinalized(identifier: String, catalogItemId: String, success: Bool) {
        guard let state = stateManager.find(where: \.instantPurchaseInitiated),
        let uxHelper = state.uxHelper as? RoktUX else { return }
        uxHelper.instantPurchaseFinalized(
            layoutId: identifier,
            catalogItemId: catalogItemId,
            success: success
        )

        if !success {
            state.onRoktEvent?(RoktEvent.CartItemInstantPurchaseFailure(
                identifier: identifier,
                catalogItemId: catalogItemId,
                cartItemId: "",
                error: nil
            ))
        }
    }

    private func devicePayFinalized(executeId: String, layoutId: String, catalogItemId: String, success: Bool) {
        guard let state = stateManager.getState(id: executeId),
              let uxHelper = state.uxHelper as? RoktUX else { return }
        uxHelper.devicePayFinalized(layoutId: layoutId, catalogItemId: catalogItemId, success: success)
    }

    private func forwardPaymentFinalized(executeId: String,
                                         layoutId: String,
                                         catalogItemId: String,
                                         success: Bool,
                                         failureReason: String? = nil) {
        guard let state = stateManager.getState(id: executeId),
              let uxHelper = state.uxHelper as? RoktUX else { return }
        uxHelper.forwardPaymentFinalized(
            layoutId: layoutId,
            catalogItemId: catalogItemId,
            success: success,
            failureReason: failureReason
        )
    }

    /// Map a UX-helper `Address` (from backend `TransactionData`) to the contracts
    /// `ContactAddress` shape expected by a `PaymentExtension`. Email is not part of
    /// `Address`, so it falls back to the partner-supplied `email` attribute.
    /// Returns `nil` if `address` is `nil`.
    func buildContactAddress(from address: RoktUXHelper.Address?) -> ContactAddress? {
        guard let address else { return nil }
        return ContactAddress(
            name: address.name,
            email: attributes["email"] ?? "",
            addressLine1: address.address1,
            city: address.city,
            state: address.stateCode.isEmpty ? address.state : address.stateCode,
            postalCode: address.zip,
            country: address.countryCode.isEmpty ? address.country : address.countryCode
        )
    }

    /// Legacy fallback: build a `ContactAddress` from partner-supplied attributes
    /// for backends that do not yet populate `TransactionData`. Returns `nil` if
    /// no address attributes were provided.
    func buildContactAddressFromAttributes() -> ContactAddress? {
        let line1 = attributes["shippingaddress1"] ?? ""
        guard !line1.isEmpty else { return nil }
        let name = [attributes["firstname"], attributes["lastname"]]
            .compactMap { $0 }
            .joined(separator: " ")
        return ContactAddress(
            name: name,
            email: attributes["email"] ?? "",
            addressLine1: line1,
            city: attributes["shippingcity"],
            state: attributes["shippingstate"],
            postalCode: attributes["shippingzipcode"],
            country: attributes["shippingcountry"]
        )
    }

    func setFrameworkType(_ frameworkType: RoktFrameworkType) {
        self.frameworkType = frameworkType
    }

    // Shows the widget on top the visible view controller
    private func showNow(payload: ExecutePayload) {
        guard !loadingFonts && isInitialized else {
            pendingPayload = payload
            return
        }
        if let layoutPage = payload.layoutPage, #available(iOS 15, *) {
            showNow(layoutPage: layoutPage,
                    startDate: payload.startDate,
                    selectionId: payload.selectionId)
        }
    }

    private func showNow(layoutPage: LayoutPageExecutePayload,
                         startDate: Date,
                         selectionId: String) {
        pendingPayload = nil
        roktEvent?(RoktEvent.HideLoadingIndicator())
        let uxHelper = RoktUX()
        initialStateBag(uxHelper: uxHelper, selectionId: selectionId)

        if let swiftUiExecuteLayout {
            uxHelper.loadLayout(
                startDate: startDate,
                experienceResponse: layoutPage.page,
                layoutPluginViewStates: layoutPage.cacheProperties?.pluginViewStates,
                defaultLayoutLoader: swiftUiExecuteLayout,
                config: roktConfig.getUXConfig(),
                onLoad: {[weak self] in self?.callOnLoad(selectionId)},
                onUnload: {[weak self] in self?.callOnUnLoad(selectionId)},
                onEmbeddedSizeChange: {[weak self] selectedPlacementName, widgetHeight in
                    self?.callOnEmbeddedSizeChange(selectionId,
                                                   selectedPlacementName: selectedPlacementName,
                                                   widgetHeight: widgetHeight)
                },
                onRoktUXEvent: { [weak self] uxEvent in
                    self?.callOnRoktUXEvent(selectionId, uxEvent: uxEvent)
                },
                onRoktPlatformEvent: { [weak self] payload in
                    self?.processedEvents?.process(payload,
                                                   executeId: selectionId,
                                                   cacheProperties: layoutPage.cacheProperties)
                }, onPluginViewStateChange: { pluginViewState in
                    layoutPage.cacheProperties?.onPluginViewStateChange?(pluginViewState)
                }
            )
        } else {
            uxHelper.loadLayout(
                startDate: startDate,
                experienceResponse: layoutPage.page,
                layoutPluginViewStates: layoutPage.cacheProperties?.pluginViewStates,
                layoutLoaders: placements,
                config: roktConfig.getUXConfig(),
                onLoad: {[weak self] in self?.callOnLoad(selectionId)},
                onUnload: {[weak self] in self?.callOnUnLoad(selectionId)},
                onEmbeddedSizeChange: {[weak self] selectedPlacementName, widgetHeight in
                    self?.callOnEmbeddedSizeChange(selectionId,
                                                   selectedPlacementName: selectedPlacementName,
                                                   widgetHeight: widgetHeight)
                },
                onRoktUXEvent: { [weak self] uxEvent in
                    self?.callOnRoktUXEvent(selectionId, uxEvent: uxEvent)
                },
                onRoktPlatformEvent: { [weak self] payload in
                    self?.processedEvents?.process(payload,
                                                   executeId: selectionId,
                                                   cacheProperties: layoutPage.cacheProperties)
                }, onPluginViewStateChange: { pluginViewState in
                    layoutPage.cacheProperties?.onPluginViewStateChange?(pluginViewState)
                }
            )
        }

        placements = nil
        _swiftUiExecuteLayout = nil
    }

    // Determines and schedules the appropriate time to show the widget
    private func show(_ payload: ExecutePayload) {
        showNow(payload: payload)
    }

    private func setSharedItems(attributes: [String: String],
                                onRoktEvent: ((RoktEvent) -> Void)?,
                                config: RoktConfig?) {
        self.roktEvent = onRoktEvent
        self.attributes = attributes
        processedEvents = PlatformEventProcessor(stateBagManager: stateManager)
        fontDiagnostics = FontDiagnosticsViewModel()
        roktConfig = config ?? roktConfig
    }

    private func isPrivacyDenied(_ status: ATTrackingManager.AuthorizationStatus) -> Bool {
        return status == .denied || status == .restricted
    }

    private func sendDiagnostics(_ message: String, error: Error, statusCode: Int?, response: String) {
        let callStack = "response: \(response) ,statusCode: \(String(describing: statusCode))" +
            " ,error: \(error.localizedDescription)"
        RoktAPIHelper.sendDiagnostics(message: message, callStack: callStack)
        RoktLogger.shared.verbose(callStack)
    }

    private func initialStateBag(uxHelper: AnyObject? = nil, selectionId: String? = nil) {
        let executeId = selectionId ?? UUID().uuidString
        stateManager.addState(
            id: executeId,
            state: ExecuteStateBag(
                uxHelper: uxHelper,
                onRoktEvent: roktEvent
            )
        )
    }

    private func callOnLoad(_ executeId: String) {
        guard let stateBag = stateManager.getState(id: executeId) else { return }
        stateManager.increasePlacements(id: executeId)
    }
    private func callOnUnLoad(_ executeId: String) {
        guard let stateBag = stateManager.getState(id: executeId) else { return }
        stateManager.decreasePlacements(id: executeId)
        if stateBag.loadedPlacements <= 0 {
            clearCallBacks()
        }
    }

    private func callOnEmbeddedSizeChange(_ executeId: String,
                                          selectedPlacementName: String,
                                          widgetHeight: CGFloat) {
        let roundedHeight = ceil(widgetHeight)

        sizeChangeWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.callOnRoktEvent(
                executeId,
                event: RoktEvent.EmbeddedSizeChanged(
                    identifier: selectedPlacementName,
                    updatedHeight: roundedHeight
                )
            )
        }
        sizeChangeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + sizeChangeDebounceInterval,
                                      execute: workItem)
    }

    private func callOnRoktUXEvent(_ executeId: String,
                                   uxEvent: RoktUXEvent) {
        if uxEvent is RoktUXEvent.FirstPositiveEngagement {
            callOnRoktEvent(executeId, event: uxEvent.mapToRoktEvent)
        } else if let event = uxEvent as? RoktUXEvent.OpenUrl {
            if event.type == .passthrough {
                callOnRoktEvent(executeId, event: uxEvent.mapToRoktEvent)
                event.onClose?(event.id)
            } else {
                linkHandler.linkHandler(urlString: event.url,
                                        type: event.type,
                                        completionHandler: {
                    event.onClose?(event.id)
                })
            }
        } else if (uxEvent as? RoktUXEvent.LayoutFailure) != nil {

            callOnRoktEvent(executeId, event: uxEvent.mapToRoktEvent)
            callOnUnLoad(executeId)
            placements = nil
            _swiftUiExecuteLayout = nil
        } else if let event = uxEvent as? RoktUXEvent.CartItemInstantPurchase {
            callOnRoktEvent(executeId, event: RoktEvent.CartItemInstantPurchaseInitiated(
                identifier: event.layoutId,
                catalogItemId: event.catalogItemId,
                cartItemId: event.cartItemId
            ))
            callOnRoktEvent(executeId, event: uxEvent.mapToRoktEvent)
        } else if let event = uxEvent as? RoktUXEvent.CartItemDevicePay {
            // Forward the public initiation and device-pay events to the partner
            callOnRoktEvent(executeId, event: RoktEvent.CartItemInstantPurchaseInitiated(
                identifier: event.layoutId,
                catalogItemId: event.catalogItemId,
                cartItemId: event.cartItemId
            ))
            callOnRoktEvent(executeId, event: uxEvent.mapToRoktEvent)

            // Map PaymentProvider -> PaymentMethodType
            let paymentMethod: PaymentMethodType
            switch event.paymentProvider.rawValue {
            case "ApplePay":
                paymentMethod = .applePay
            case "Stripe":
                paymentMethod = .card
            case "Afterpay":
                paymentMethod = .afterpay
            default:
                RoktLogger.shared.error("Unsupported payment provider: \(event.paymentProvider.rawValue)")
                devicePayFinalized(executeId: executeId, layoutId: event.layoutId,
                                   catalogItemId: event.catalogItemId, success: false)
                return
            }

            // Build PaymentItem from event data
            let amount = event.totalPrice ?? event.unitPrice ?? 0
            let item = PaymentItem(
                id: event.catalogItemId,
                name: event.name,
                amount: amount,
                currency: event.currency
            )

            // Build PaymentContext from backend-provided TransactionData, falling
            // back to partner-supplied attributes if the offer did not include
            // transaction data (e.g. older backend versions).
            let context: PaymentContext
            if paymentMethod == .afterpay {
                let billing = buildContactAddress(from: event.transactionData?.billingAddress)
                    ?? buildContactAddressFromAttributes()
                let shipping = buildContactAddress(from: event.transactionData?.shippingAddress)
                    ?? buildContactAddressFromAttributes()
                context = PaymentContext(billingAddress: billing, shippingAddress: shipping)
            } else {
                context = PaymentContext()
            }

            // Find the topmost view controller for presenting the payment sheet
            guard let viewController = UIApplication.topViewController() else {
                RoktLogger.shared.error("No view controller available to present payment sheet")
                devicePayFinalized(executeId: executeId, layoutId: event.layoutId,
                                   catalogItemId: event.catalogItemId, success: false)
                return
            }

            // Process the payment via the registered extension
            paymentOrchestrator.processPayment(
                method: paymentMethod,
                item: item,
                context: context,
                cartItemId: event.cartItemId,
                from: viewController
            ) { [weak self] result in
                let success = result.outcome == .succeeded
                if success {
                    self?.callOnRoktEvent(executeId, event: RoktEvent.CartItemInstantPurchase(
                        identifier: event.layoutId,
                        name: event.name,
                        cartItemId: event.cartItemId,
                        catalogItemId: event.catalogItemId,
                        currency: event.currency,
                        description: event.description,
                        linkedProductId: event.linkedProductId,
                        providerData: event.providerData,
                        quantity: NSDecimalNumber(decimal: event.quantity),
                        totalPrice: event.totalPrice.map { NSDecimalNumber(decimal: $0) },
                        unitPrice: event.unitPrice.map { NSDecimalNumber(decimal: $0) }
                    ))
                } else {
                    self?.callOnRoktEvent(executeId, event: RoktEvent.CartItemInstantPurchaseFailure(
                        identifier: event.layoutId,
                        catalogItemId: event.catalogItemId,
                        cartItemId: event.cartItemId,
                        error: nil
                    ))
                }
                self?.devicePayFinalized(
                    executeId: executeId,
                    layoutId: event.layoutId,
                    catalogItemId: event.catalogItemId,
                    success: success
                )
            }
        } else if let event = uxEvent as? RoktUXEvent.CartItemForwardPayment {
            handleForwardPayment(executeId: executeId, event: event)
        } else {
            callOnRoktEvent(executeId, event: uxEvent.mapToRoktEvent)
        }
    }

    /// Resolve the unit and total price for a forward-payment event.
    ///
    /// - If both are present, use them as-is.
    /// - If only `unitPrice` is present, derive `totalPrice = unitPrice * quantity`.
    /// - If only `totalPrice` is present, derive `unitPrice = totalPrice / quantity`
    ///   (requires `quantity > 0`).
    /// - Returns `nil` if neither is present, or if only `totalPrice` is present
    ///   with a non-positive `quantity`.
    static func resolveForwardPaymentPrices(
        unitPrice: Decimal?,
        totalPrice: Decimal?,
        quantity: Decimal
    ) -> (unitPrice: Decimal, totalPrice: Decimal)? {
        switch (unitPrice, totalPrice) {
        case let (unit?, total?):
            return (unit, total)
        case let (unit?, nil):
            return (unit, unit * quantity)
        case let (nil, total?) where quantity > 0:
            return (total/quantity, total)
        default:
            return nil
        }
    }

    static func buildForwardPaymentRequest(
        from event: RoktUXEvent.CartItemForwardPayment,
        fulfillmentDetails: FulfillmentDetails? = nil
    ) -> PurchaseRequest? {
        guard let prices = resolveForwardPaymentPrices(
            unitPrice: event.unitPrice,
            totalPrice: event.totalPrice,
            quantity: event.quantity
        ) else {
            return nil
        }

        let item = UpsellItem(
            cartItemId: event.cartItemId,
            catalogItemId: event.catalogItemId,
            quantity: event.quantity,
            unitPrice: prices.unitPrice,
            totalPrice: prices.totalPrice,
            currency: event.currency
        )

        return PurchaseRequest(
            totalUpsellPrice: prices.totalPrice,
            currency: event.currency,
            upsellItems: [item],
            paymentDetails: PurchasePaymentDetails(
                token: nil,
                partnerPaymentReference: event.partnerPaymentReference
            ),
            fulfillmentDetails: fulfillmentDetails
        )
    }

    /// Build `FulfillmentDetails` from partner-supplied shipping attributes.
    /// Returns `nil` if no shipping address was provided — caller should fall
    /// through to a server-side error rather than sending `{}`.
    func buildFulfillmentDetailsFromAttributes() -> FulfillmentDetails? {
        guard let contactAddress = buildContactAddressFromAttributes() else {
            return nil
        }
        return FulfillmentDetails(
            shippingAttributes: ShippingAttributes(from: contactAddress)
        )
    }

    static func resolveForwardPaymentFinalization(
        from response: PurchaseResponse
    ) -> (success: Bool, failureReason: String?) {
        if response.success {
            return (true, nil)
        }

        return (false, response.reason ?? unknownForwardPaymentFailureReason)
    }

    static func resolveForwardPaymentFinalization(
        fromFailureMessage message: String
    ) -> (success: Bool, failureReason: String?) {
        let failureReason = message.isEmpty ? unknownForwardPaymentFailureReason : message
        return (false, failureReason)
    }

    private func handleForwardPayment(executeId: String,
                                      event: RoktUXEvent.CartItemForwardPayment) {
        let fulfillmentDetails = buildFulfillmentDetailsFromAttributes()
        guard let request = Self.buildForwardPaymentRequest(
            from: event,
            fulfillmentDetails: fulfillmentDetails
        ) else {
            RoktLogger.shared.warning(
                "Forward-payment event missing price or has non-positive quantity"
            )
            forwardPaymentFinalized(
                executeId: executeId,
                layoutId: event.layoutId,
                catalogItemId: event.catalogItemId,
                success: false,
                failureReason: Self.missingForwardPaymentPriceReason
            )
            return
        }

        RoktAPIHelper.forwardPayment(
            request: request,
            success: { [weak self] response in
                let finalization = Self.resolveForwardPaymentFinalization(from: response)
                self?.forwardPaymentFinalized(
                    executeId: executeId,
                    layoutId: event.layoutId,
                    catalogItemId: event.catalogItemId,
                    success: finalization.success,
                    failureReason: finalization.failureReason
                )
            },
            failure: { [weak self] _, _, message in
                let finalization = Self.resolveForwardPaymentFinalization(
                    fromFailureMessage: message
                )
                self?.forwardPaymentFinalized(
                    executeId: executeId,
                    layoutId: event.layoutId,
                    catalogItemId: event.catalogItemId,
                    success: finalization.success,
                    failureReason: finalization.failureReason
                )
            }
        )
    }

    private func callOnRoktEvent(_ executeId: String,
                                 event: RoktEvent?) {
        if let event,
            let stateBag = stateManager.getState(id: executeId) {
            stateBag.onRoktEvent?(event)
        }
    }

    private func conclude(withFailure: Bool = false) {
        roktEvent?(RoktEvent.HideLoadingIndicator())

        if withFailure {
            roktEvent?(RoktEvent.PlacementFailure(identifier: nil))
        }

        clearCallBacks()
    }

    func clearCallBacks() {
        placements = nil
        roktEvent = nil
    }

    private func sentEventToListeners(viewName: String?, roktEvent: RoktEvent) {
        if let viewName, let eventListener = roktEventMap[viewName] {
            eventListener?(roktEvent)
        }
    }

    func initWith(
        roktTagId: String,
        mParticleKitDetails: MParticleKitDetails?
    ) {
        RoktLogger.shared.info("initWithCallback called with tagId: \(roktTagId.prefix(8))..., " +
                               "mParticleKitDetails: \(mParticleKitDetails != nil ? "present" : "nil")")

        let initStartTime = RoktSDKDateHandler.currentDate()

        if let mParticleKitDetails {
            RoktLogger.shared.debug("Updating mParticle kit details")
            NetworkingHelper.updateMParticleKitDetails(mParticleKitDetails: mParticleKitDetails)
        }

        self.roktTagId = roktTagId
        sessionManager.storedTagId = roktTagId
        isInitFailedForFont = false
        stateManager = StateBagManager()

        setupFontObservers()

        RoktLogger.shared.debug("Starting API initialization request")
        RoktAPIHelper.initialize(roktTagId: roktTagId,
                                 success: { (initResponse) in
            RoktLogger.shared.info("API initialization succeeded")
            self.isInitialized = true
            self.initFeatureFlags = initResponse.featureFlags

            self.processedTimingsRequests = TimingsRequestProcessor()
            self.processedTimingsRequests?.setInitStartTime(initStartTime)

            self.clientTimeoutMilliseconds = initResponse.timeout != 0 ?
            initResponse.timeout : self.clientTimeoutMilliseconds
            self.defaultLaunchDelayMilliseconds = initResponse.delay != 0 ?
            initResponse.delay : self.defaultLaunchDelayMilliseconds
            if let clientSessionTimeoutMilliseconds = initResponse.clientSessionTimeout {
                self.sessionManager.currentSessionDurationSeconds = clientSessionTimeoutMilliseconds/1000
            }
            NetworkingHelper.updateTimeout(timeout: self.clientTimeoutMilliseconds/1000)

            let initFonts = initResponse.fonts
            RoktLogger.shared.debug("Downloading \(initFonts.count) font(s)")
            FontManager.removeUnusedFonts(fonts: initFonts)
            RoktAPIHelper.downloadFonts(initFonts) {
                let success = self.isInitialized && !self.isInitFailedForFont
                RoktLogger.shared.info("Initialization complete - success: \(success)")
                if let eventListener = self.roktEventMap[Self.defaultRoktInitEvent] {
                    eventListener?(RoktEvent.InitComplete(success: success))
                }
            }
        }, failure: { (error, statusCode, response) in
            RoktLogger.shared.error("Initialization failed - statusCode: \(statusCode ?? -1), " +
                                    "error: \(error.localizedDescription)")
            self.isInitialized = false
            self.processedTimingsRequests?.setInitEndTime()
            // Don't report diagnostics for 429 (Too Many Requests) status code
            if let code = statusCode, code != 429 {
                self.sendDiagnostics(Self.initDiagnosticCode, error: error, statusCode: statusCode, response: response)
            }
            if let eventListener = self.roktEventMap[Self.defaultRoktInitEvent] {
                eventListener?(RoktEvent.InitComplete(success: false))
            }
        })
    }

    /// Rokt developer facing execute
    ///
    /// - Parameters:
    ///   - viewName: The name that should be displayed in the widget
    ///   - attributes: A string dictionary containing the parameters that should be displayed in the widget
    ///   - placements: A dictionary of RoktEmbeddedViews with their names
    ///   - config: An object which defines RoktConfig
    ///   - placementOptions: Optional placement options containing timing data from joint SDKs
    ///   Placement and second item is widget height
    func execute(
        viewName: String? = nil,
        attributes: [String: String],
        placements: [String: RoktEmbeddedView]? = nil,
        config: RoktConfig?,
        placementOptions: RoktPlacementOptions? = nil,
        onRoktEvent: ((RoktEvent) -> Void)? = nil
    ) {
        let composedEventHandler: (RoktEvent) -> Void = { event in
            onRoktEvent?(event)
            self.sentEventToListeners(viewName: viewName, roktEvent: event)
        }

        // Generate a unique selectionId for this execute call
        let selectionId = UUID().uuidString

        func preExecuteFailureHandler() {
            composedEventHandler(RoktEvent.HideLoadingIndicator())
            composedEventHandler(RoktEvent.PlacementFailure(identifier: nil))
            RoktAPIHelper.sendDiagnostics(message: Self.notInitializedDiagnosticCode,
                                          callStack: isInitFailedForFont ? Self.fontFailedError : Self.initFailedError,
                                          severity: .info)
        }

        func onExperiencesRequestStart() {
            processedTimingsRequests?.setExperiencesRequestStartTime(selectionId: selectionId)
        }

        func onExperiencesRequestEnd() {
            processedTimingsRequests?.setExperiencesRequestEndTime(selectionId: selectionId)
            processedTimingsRequests?.setSelectionEndTime(selectionId: selectionId)
        }

        processedTimingsRequests?.resetPageTimings(selectionId: selectionId)
        processedTimingsRequests?.setSelectionStartTime(selectionId: selectionId)
        if let placementOptions = placementOptions {
            processedTimingsRequests?.setJointSdkSelectPlacements(
                selectionId: selectionId,
                timestamp: placementOptions.jointSdkSelectPlacements
            )
        }
        if isExecuting || !isInitialized {
            RoktLogger.shared.warning("Execute called while already running or SDK not initialized")
            preExecuteFailureHandler()
            return
        }
        var trackingConsent: UInt?
        if #available(iOS 14.5, *) {
            if !initFeatureFlags.isEnabled(.roktTrackingStatus) &&
                isPrivacyDenied(ATTrackingManager.trackingAuthorizationStatus) {
                RoktAPIHelper.sendDiagnostics(
                    message: Self.trackingConsentDiagnosticCode,
                    callStack: Self.trackingConsentError,
                    severity: .warning
                )
                preExecuteFailureHandler()
                return
            }
            trackingConsent = ATTrackingManager.trackingAuthorizationStatus.rawValue
        }

        isExecuting = true
        self.placements = placements
        let startDate = Date()
        if let tagId = roktTagId {
            composedEventHandler(RoktEvent.ShowLoadingIndicator())
            setSharedItems(attributes: attributes,
                           onRoktEvent: composedEventHandler, config: config)

            if #available(iOS 15, *) {
                FontManager.reRegisterFonts {
                    // use the available cached experience
                    let cacheAttributes = self.roktConfig.cacheConfig.getCacheAttributesOrFallback(attributes)

                    if self.isCacheEnabledAndConfigured(),
                       let cachedExperience = ExperienceCacheManager.getCachedExperienceResponse(
                           viewName: viewName,
                           attributes: cacheAttributes,
                           cacheDuration: self.roktConfig.cacheConfig.cacheDuration
                       ) {
                        onExperiencesRequestEnd()
                        self.isExecuting = false

                        guard let layoutPageExecutePayload = self.processLayoutPageExecutePayload(
                            cachedExperience, selectionId: selectionId, viewName: viewName, attributes: attributes
                        ) else {
                            self.conclude(withFailure: true)
                            return
                        }

                        RoktAPIHelper.sendDiagnostics(message: Self.cacheHitDiagnosticCode,
                                                      callStack: String(format: Self.cacheHitMessage, viewName ?? ""),
                                                      severity: .info,
                                                      additionalInfo: [
                                                          Self.cacheDurationKey: String(self.roktConfig.cacheConfig
                                                              .cacheDuration),
                                                          Self.cacheAttributesKey: Array(cacheAttributes.keys).description
                                                      ])

                        let payload = ExecutePayload(layoutPage: layoutPageExecutePayload,
                                                     startDate: startDate,
                                                     selectionId: selectionId)
                        self.show(payload)
                    } else {
                        RoktAPIHelper.getExperienceData(
                            viewName: viewName,
                            attributes: attributes,
                            roktTagId: tagId,
                            selectionId: selectionId,
                            trackingConsent: trackingConsent,
                            config: self.roktConfig,
                            onRequestStart: onExperiencesRequestStart,
                            successLayout: { page in
                                onExperiencesRequestEnd()
                                self.isExecuting = false

                                guard let page else {
                                    self.conclude(withFailure: true)
                                    return
                                }
                                // cache experience if applicable
                                if self.isCacheEnabledAndConfigured() {
                                    let cacheAttributes = self.roktConfig.cacheConfig.getCacheAttributesOrFallback(attributes)

                                    DispatchQueue.background.async {
                                        ExperienceCacheManager.cacheExperienceResponse(
                                            viewName: viewName,
                                            attributes: cacheAttributes,
                                            experienceResponse: page
                                        )
                                    }
                                }

                                // Use cacheAttributes for plugin view states if cache is enabled for consistency
                                let attributesForPluginStates = self.roktConfig.cacheConfig
                                    .getCacheAttributesOrFallback(attributes)
                                guard let layoutPageExecutePayload = self.processLayoutPageExecutePayload(
                                    page, selectionId: selectionId, viewName: viewName, attributes: attributesForPluginStates
                                ) else {
                                    self.conclude(withFailure: true)
                                    return
                                }

                                let payload = ExecutePayload(
                                    layoutPage: layoutPageExecutePayload,
                                    startDate: startDate,
                                    selectionId: selectionId
                                )
                                self.show(payload)
                            },
                            failure: { (error, statusCode, response) in
                                onExperiencesRequestEnd()
                                self.executeFailureHandler(error, statusCode, response)
                            }
                        )}
                }
            }
        } else {
            isExecuting = false
            RoktLogger.shared.error("SDK is not initialized - cannot execute")
            composedEventHandler(RoktEvent.PlacementFailure(identifier: nil))
            clearCallBacks()
            RoktAPIHelper.sendDiagnostics(message: Self.notInitializedDiagnosticCode,
                                          callStack: isInitFailedForFont ? Self.fontFailedError : Self.initFailedError,
                                          severity: .info)
        }
    }

    private func isCacheEnabledAndConfigured() -> Bool {
        return initFeatureFlags.isEnabled(.cacheEnabled) && roktConfig.cacheConfig.isCacheEnabled()
    }

    func processLayoutPageExecutePayload(_ page: String,
                                         selectionId: String,
                                         viewName: String? = nil,
                                         attributes: [String: String]) -> LayoutPageExecutePayload? {
        guard let pageData = page.data(using: .utf8) else {
            return nil
        }

        guard let pageDecodedData = try? decodeOnSeparateThread(RoktUXExperienceResponse.self, pageData) else {
            return nil
        }
        sessionManager.updateSessionId(newSessionId: pageDecodedData.sessionId)

        guard let pageModel = pageDecodedData.getPageModel() else {
            return nil
        }
        let events = try? decodeOnSeparateThread(UntriggeredEventsContainer.self, pageData)
        if let events = events {
            RealTimeEventManager.shared.addUntriggeredEvents(events.untriggeredEvents)
        }

        processedTimingsRequests?.setPageProperties(
            selectionId: selectionId,
            sessionId: pageDecodedData.sessionId,
            pageId: pageModel.pageId,
            pageInstanceGuid: pageModel.pageInstanceGuid
        )

        if isCacheEnabledAndConfigured() {
            // For cached experiences, use cacheAttributes for consistency
            let cacheAttributes = roktConfig.cacheConfig.getCacheAttributesOrFallback(attributes)
            let experiencesViewState = ExperienceCacheManager.getCachedExperiencesViewState(
                viewName: viewName, attributes: cacheAttributes
            )
            sentEventHashes = ThreadSafeSet(Array(experiencesViewState?.sentEventHashes ?? .init()))

            let pluginViewStates = getLayoutPluginViewStates(pageModel: pageModel,
                                                             viewName: viewName,
                                                             attributes: cacheAttributes)

            func onPluginViewStateChange(_ pluginViewStateUpdates: RoktPluginViewState) {
                ExperienceCacheManager.updatePluginViewStateCache(
                    viewName: viewName,
                    attributes: cacheAttributes,
                    updateStates: pluginViewStateUpdates
                )
            }

            let cacheProperties = LayoutPageCacheProperties(
                viewName: viewName,
                attributes: attributes,
                pluginViewStates: pluginViewStates,
                onPluginViewStateChange: onPluginViewStateChange
            )
            return LayoutPageExecutePayload(page: page,
                                            cacheProperties: cacheProperties)
        } else {
            return LayoutPageExecutePayload(page: page,
                                            cacheProperties: nil)
        }
    }

    private func getLayoutPluginViewStates(pageModel: RoktUXPageModel,
                                           viewName: String?,
                                           attributes: [String: String]) -> [RoktPluginViewState]? {
        guard let layoutPlugins = pageModel.layoutPlugins else { return nil }
        return layoutPlugins.compactMap { (plugin) -> RoktPluginViewState? in
            return ExperienceCacheManager.getOrCreateCachedPluginViewState(
                pluginId: plugin.pluginId, viewName: viewName, attributes: attributes
            )
        }
    }

    func swiftUiExecute(
        viewName: String? = nil,
        attributes: [String: String],
        layout: LayoutLoader? = nil,
        config: RoktConfig? = nil,
        placementOptions: RoktPlacementOptions? = nil,
        onRoktEvent: ((RoktEvent) -> Void)? = nil
    ) {
        _swiftUiExecuteLayout = layout
        execute(
            viewName: viewName,
            attributes: attributes,
            config: config,
            placementOptions: placementOptions,
            onRoktEvent: {roktEvent in
                onRoktEvent?(roktEvent)
            }
        )
    }

    internal func executeFailureHandler(_ error: Error, _ statusCode: Int?, _ response: String) {
        isExecuting = false
        // Don't report diagnostics for 429 (Too Many Requests) status code
        if let code = statusCode, code != 429 {
            sendDiagnostics(Self.executeDiagnosticCode, error: error, statusCode: statusCode, response: response)
        }
        conclude(withFailure: true)
    }

    func mapEvents(
        viewName: String = "",
        isGlobal: Bool = false,
        onEvent: ((RoktEvent) -> Void)?
    ) {
        if isGlobal, viewName.isEmpty {
            roktEventMap[Self.defaultRoktInitEvent] = onEvent
        } else {
            roktEventMap[viewName] = onEvent
        }
    }

    func setSessionId(sessionId: String) {
        guard !sessionId.isEmpty else {
            return
        }
        sessionManager.updateSessionId(newSessionId: sessionId)
    }

    func getSessionId() -> String? {
        return sessionManager.getCurrentSessionIdWithoutExpiring()
    }

    private func setupFontObservers() {
        // Clean up existing observers
        fontLoadObservers.forEach { NotificationCenter.default.removeObserver($0) }
        fontLoadObservers.removeAll()

        // Observer for started loading fonts
        let startedObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name(FontManager.downloadingFonts),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadingFonts = true
        }

        // Observer for finished loading fonts
        let finishedObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name(finishedDownloadingFonts),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.loadingFonts = false
            self.processedTimingsRequests?.setInitEndTime()

            if let page = self.pendingPayload {
                self.showNow(payload: page)
            }
        }

        fontLoadObservers.append(contentsOf: [startedObserver, finishedObserver])
    }

    // MARK: - Payment Extension

    /// Register a payment extension for Shoppable Ads.
    func registerPaymentExtension(_ paymentExtension: PaymentExtension, config: [String: String]) {
        if !paymentOrchestrator.register(paymentExtension, config: config) {
            RoktLogger.shared.error("Rokt: Failed to register payment extension: \(paymentExtension.id)")
            RoktAPIHelper.sendDiagnostics(
                message: PaymentOrchestrator.devicePayErrorCode,
                callStack: "Failed to register payment extension: \(paymentExtension.id)",
                severity: .warning
            )
        }
    }

    /// Forward a URL to registered payment extensions.
    @discardableResult
    func handleURLCallback(with url: URL) -> Bool {
        paymentOrchestrator.handleURLCallback(with: url)
    }

    // MARK: - Shoppable Ads

    private let keyAdsExperienceType = "adsExperience"
    private let valueAdsExperienceShoppable = "shoppable"

    /// Display a Shoppable Ads overlay placement.
    func selectShoppableAds(
        identifier: String,
        attributes: [String: String],
        config: RoktConfig?,
        onRoktEvent: ((RoktEvent) -> Void)?
    ) {
        if isInitialized && !initFeatureFlags.isShoppableAdsEnabled() {
            RoktLogger.shared.verbose(
                "Rokt: selectShoppableAds skipped — Shoppable Ads feature flags are disabled for this account."
            )
            onRoktEvent?(RoktEvent.PlacementFailure(identifier: nil))
            return
        }

        guard paymentOrchestrator.hasRegisteredExtension else {
            RoktLogger.shared.error(
                "Rokt: No PaymentExtension registered. Call registerPaymentExtension() before selectShoppableAds()."
            )
            onRoktEvent?(RoktEvent.PlacementFailure(identifier: nil))
            return
        }

        var enrichedAttributes = attributes
        if enrichedAttributes[keyAdsExperienceType] == nil {
            enrichedAttributes[keyAdsExperienceType] = valueAdsExperienceShoppable
        }

        // Reuse the existing execute flow — backend routes based on placement config
        execute(
            viewName: identifier,
            attributes: enrichedAttributes,
            placements: nil,
            config: config,
            placementOptions: nil,
            onRoktEvent: onRoktEvent
        )
    }

    private func decodeOnSeparateThread<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        var result: Result<T, Error>?
        let semaphore = DispatchSemaphore(value: 0)

        let decodingThread = Thread {
            defer { semaphore.signal() }
            do {
                let decoded = try JSONDecoder().decode(type, from: data)
                result = .success(decoded)
            } catch {
                result = .failure(error)
            }
        }
        decodingThread.name = "com.rokt.decoder"
        decodingThread.stackSize = max(decodingThread.stackSize, 8 * 1024 * 1024)
        decodingThread.qualityOfService = Thread.current.qualityOfService
        decodingThread.start()

        semaphore.wait()

        switch result {
        case .success(let decoded):
            return decoded
        case .failure(let error):
            throw error
        case .none:
            throw RoktError("Decoding failed")
        }
    }
}

struct ExecutePayload {
    let layoutPage: LayoutPageExecutePayload?
    let startDate: Date
    let selectionId: String
}

struct LayoutPageExecutePayload {
    let page: String
    let cacheProperties: LayoutPageCacheProperties?
}

struct LayoutPageCacheProperties {
    let viewName: String?
    let attributes: [String: String]
    let pluginViewStates: [RoktPluginViewState]?
    let onPluginViewStateChange: ((RoktPluginViewState) -> Void)?
}
