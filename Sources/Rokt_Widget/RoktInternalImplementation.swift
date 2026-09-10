import Foundation
import UIKit
import AppTrackingTransparency
import RoktContracts
internal import DcuiSchema
internal import RoktUXHelper

class RoktInternalImplementation {
    private static let initDiagnosticCode = "[INIT]"
    private static let executeDiagnosticCode = "[EXECUTE]"
    private static let trackingConsentDiagnosticCode = "[TRACKINGCONSENT]"
    private static let notInitializedDiagnosticCode = "[NOT_INITIALIZED]"
    private static let cacheHitDiagnosticCode = "[CACHE_HIT]"
    private static let cacheHitMessage = "Cache hit for view - %@"
    private static let urlOpenErrorDomain = "com.rokt.sdk.url"
    private static let urlOpenErrorCode = 1
    private static let urlOpenErrorDescription = "The destination URL could not be opened."
    // Public-API-usage diagnostics (INFO severity). Keep this a small, bounded set of codes.
    static let apiInitCode = "[API_INIT]"
    static let apiInitMParticleCode = "[API_INIT_MPARTICLE]"
    static let apiSelectPlacementsCode = "[API_SELECT_PLACEMENTS]"
    static let apiLayoutCode = "[API_LAYOUT]"
    static let apiSelectShoppableAdsCode = "[API_SELECT_SHOPPABLE_ADS]"
    static let apiPurchaseFinalizedCode = "[API_PURCHASE_FINALIZED]"
    static let apiEventsCode = "[API_EVENTS]"
    static let apiGlobalEventsCode = "[API_GLOBAL_EVENTS]"
    static let apiCloseCode = "[API_CLOSE]"
    static let apiRegisterPaymentExtensionCode = "[API_REGISTER_PAYMENT_EXTENSION]"
    static let apiSetCustomBaseURLCode = "[API_SET_CUSTOM_BASE_URL]"
    static let apiSetFrameworkTypeCode = "[API_SET_FRAMEWORK_TYPE]"
    static let apiGetSessionIdCode = "[API_GET_SESSION_ID]"
    static let apiSetSessionIdCode = "[API_SET_SESSION_ID]"
    static let apiClearSessionCode = "[API_CLEAR_SESSION]"
    static let apiHandleURLCallbackCode = "[API_HANDLE_URL_CALLBACK]"
    static let apiSetPayPalRedirectSchemeCode = "[API_SET_PAYPAL_REDIRECT_SCHEME]"
    private static let maxPendingApiLogs = 10
    private static let initFailedError = "INIT_FAILED"
    private static let fontFailedError = "FONT_FAILED"
    private static let trackingConsentError = "tracking consent not authorised"
    // TxnInitService already retries 5xx and transport blips inside a single request. These
    // recover from a whole failed init - a cold start with no network, or a 429 burst - which
    // otherwise leaves the SDK uninitialised until the process restarts.
    private static let initRecoveryDelaysSeconds: [TimeInterval] = [2, 8, 30]
    private static let rateLimitedStatusCode = 429
    private static let cacheDurationKey = "cacheDuration"
    private static let cacheAttributesKey = "cacheAttributeKeys"
    static let missingForwardPaymentPriceReason = "Missing price on forward-payment event"
    static let unknownForwardPaymentFailureReason = "Unknown failure reason"
    static let defaultTimeoutMilliseconds: Double = 9000
    static let defaultFontTimeoutSeconds: Double = 30
    static let defaultDelay: Double = 1000
    private static let builtInPayPalMissingRedirectSchemeMessage =
        "Rokt: Built-in PayPal device pay requires Rokt.setBuiltInPayPalRedirectURLScheme(_:) "
            + "with a bare URL scheme registered in Info.plist (CFBundleURLTypes / CFBundleURLSchemes)."

    var roktTagId: String?
    // Identifies the latest init request so a superseded init's async completion is ignored.
    private var initGeneration = 0
    private var initRecoveryAttempt = 0
    let sessionManager: SessionManager
    var attributes = [String: String]()
    var isInitialized = false
    var isInitFailedForFont = false
    private(set) var frameworkType: RoktFrameworkType = .iOS
    // Public-API logs that arrive before init (setCustomBaseURL / setFrameworkType). Held until init
    // sets `roktTagId`, then flushed — the diagnostics send needs the tag id for partner attribution.
    private var pendingApiLogs: [(code: String, info: [String: String])] = []
    private let pendingApiLogsLock = NSLock()
    var processedEvents: PlatformEventProcessor?
    var fontDiagnostics = FontDiagnosticsViewModel()
    // Feature flags
    var initFeatureFlags: InitFeatureFlags = InitFeatureFlags(roktTrackingStatus: true,
                                                              shouldLogFontHappyPath: false,
                                                              shouldUseFontRegisterWithUrl: false,
                                                              featureFlags: [:])
    var processedTimingsRequests: TimingsRequestProcessor?

    var stateManager: StateBagManaging = StateBagManager()

    // Layout schema version sent on init requests.
    private static var txnLayoutSchemaVersion: String {
        RoktUX.integrationInfo.integration.layoutSchemaVersion
            .split(separator: ".").prefix(2).joined(separator: ".")
    }
    // Test-only override for the init service factory; nil uses the real builder.
    var makeTxnInitServiceOverride: ((String) -> TxnInitService)?
    var initRecoveryScheduler: (TimeInterval, @escaping () -> Void) -> Void = { delay, work in
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
    // Test-only override for the offers service factory; nil uses the real builder.
    var makeOffersServiceOverride: ((String) -> OffersService)?

    // Test-only override for the events service factory; nil uses the real builder.
    var makeTxnEventServiceOverride: ((String) -> TxnEventService)?
    // Test-only hook, run once a cached experience has been read and before it is committed; nil in production.
    var unitTest_beforeCacheHitCommit: (() -> Void)?
    // Test-only hook, run once a cached experience is committed and before the render is re-checked; nil in production.
    var unitTest_afterCacheHitCommit: (() -> Void)?
    // Test-only hook, run while a placement's starting state is being read under the generation lock; nil in production.
    var unitTest_duringPlacementStart: (() -> Void)?
    // Test-only hook, run before a placement's offers service is built and its generation re-checked; nil in production.
    var unitTest_beforeOffersServiceBuilt: (() -> Void)?
    private var pendingPayload: ExecutePayload?
    private var clientTimeoutMilliseconds: Double = RoktInternalImplementation.defaultTimeoutMilliseconds
    private var defaultLaunchDelayMilliseconds: Double = RoktInternalImplementation.defaultDelay
    private var isExecuting = false
    private var placements: [String: RoktEmbeddedView]?
    // The selection id of the placement that currently owns `roktEvent` and `placements`. A placement whose result
    // is discarded after clearSession clears them only while they are still its own (see concludeDiscarded).
    private var executingSelectionId: String?

    // Bumped by clearSession and captured when an execute starts; a completion from an earlier
    // generation is discarded. Covers what the txn store's epoch does not: the legacy session id,
    // the real-time event store, the experience cache and the render itself.
    private var sessionGeneration = 0
    // Recursive so a managed session invalidated under the lock may read the generation. Held only for bounded local
    // work (a commit's parse, a placement's start, and the synchronous hand-off of one offers request to the network
    // stack in handOffIfCurrent) and never across a wait on a response.
    private let sessionGenerationLock = NSRecursiveLock()

    // Caching is disabled by default when no CacheConfig is provided to the Builder.
    var roktConfig: RoktConfig = RoktConfig.Builder().build()

    private let linkHandler: LinkHandler
    var sentEventHashes: ThreadSafeSet<String> = .init()

    // Persists unsent event batches so an offline/rate-limited failure is replayed on the next init.
    // Test-only override; production always uses the default file-backed store.
    var txnPendingEventStore: TxnPendingEventStoring = TxnPendingEventStore()

    // Backing store for the txn session. Test-only override; production uses UserDefaults.
    var txnSessionStore: TxnSessionStore = UserDefaultsTxnSessionStore()

    // Set by clearSession, latched into cacheSuppressedForCurrentExecute at the start of every
    // execute and only disarmed once one of them fetches a fresh experience. A cache hit satisfies
    // a placement without a network call, and the server is what mints a session — so until the
    // new session has fetched something, nothing left on disk may be served.
    private var mustBypassCacheOnNextExecute = false

    // Suppresses every cache read within one execute: the experience response and the view state
    // (sentEventHashes, plugin view states). Without covering the view state too, the next customer
    // inherits the previous one's sent-event hashes and UI progress from files the asynchronous
    // clearCache has not deleted yet.
    private var cacheSuppressedForCurrentExecute = false

    // Flushes buffered events when the app backgrounds so they are not lost in the debounce window.
    // periphery:ignore - held only for its side effect (registers the didEnterBackground observer); never read.
    private let eventFlushLifecycleObserver = EventFlushLifecycleObserver()

    // store callback for partner event integration
    private var roktEvent: ((RoktEvent) -> Void)?
    private var roktEventMap: [String: ((RoktEvent) -> Void)?] = [:]

    // Multicast: the mParticle kit and the host app both subscribe through Rokt.globalEvents,
    // so a single slot let whichever registered last silently unsubscribe the other.
    private var globalEventListeners: [(RoktEvent) -> Void] = []
    private let globalEventListenersLock = NSLock()

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

    // Exposes `PaymentOrchestrator` for unit tests that exercise built-in card forwarding.
    // periphery:ignore
    internal var paymentOrchestratorForTesting: PaymentOrchestrator { paymentOrchestrator }

    /// Bare URL scheme (no `://`) for built-in PayPal device-pay redirects: `\(scheme)://rokt-paypal-return` / `rokt-paypal-cancel`.
    /// Set via ``Rokt/setBuiltInPayPalRedirectURLScheme(_:)`` before PayPal device pay; required for that flow.
    private var builtInPayPalRedirectURLScheme: String?

    var isPaymentExtensionRegistered: Bool { paymentOrchestrator.hasRegisteredExtension }
    var availablePaymentMethods: [PaymentMethodType] {
        paymentOrchestrator.availablePaymentMethods(isBuiltInPayPalAvailable: builtInPayPalRedirectURLScheme != nil)
    }

    func close() {
        RoktAPIHelper.logApiCalled(Self.apiCloseCode)
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

    /// Rokt private initializer. Only available for the singleton object `shared`.
    /// `sessionManager` is injectable so tests can use a scratch `UserDefaults` suite
    /// instead of writing session state into `.standard`.
    init(sessionManager: SessionManager? = nil, linkHandler: LinkHandler = LinkHandler()) {
        let managedSessionObjects = [RealTimeEventManager.shared]
        self.sessionManager = sessionManager ?? SessionManager(managedSessions: managedSessionObjects)
        self.linkHandler = linkHandler
        NetworkingHelper.updateTimeout(timeout: clientTimeoutMilliseconds/1000)
    }

    func purchaseFinalized(identifier: String, catalogItemId: String, success: Bool) {
        RoktAPIHelper.logApiCalled(Self.apiPurchaseFinalizedCode, ["success": "\(success)"])
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

    private func devicePayRetry(executeId: String, layoutId: String, catalogItemId: String) {
        guard let state = stateManager.getState(id: executeId),
              let uxHelper = state.uxHelper as? RoktUX else { return }
        uxHelper.devicePayRetry(layoutId: layoutId, catalogItemId: catalogItemId)
    }

    private func forwardPaymentFinalized(executeId: String,
                                         layoutId: String,
                                         catalogItemId: String,
                                         success: Bool,
                                         failureReason: String? = nil) {
        defer { stateManager.finishInstantPurchase(id: executeId) }
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
            name: resolvedContactName(address.name),
            email: attributes["email"] ?? "",
            addressLine1: address.address1,
            addressLine2: address.address2,
            city: address.city,
            state: address.stateCode.isEmpty ? address.state : address.stateCode,
            postalCode: address.zip,
            country: address.countryCode.isEmpty ? address.country : address.countryCode
        )
    }

    /// Fallback: build a `ContactAddress` from partner-supplied attributes
    /// when `TransactionData` has no address. Returns `nil` if
    /// no address attributes were provided.
    func buildContactAddressFromAttributes() -> ContactAddress? {
        let line1 = attributes["shippingaddress1"] ?? ""
        guard !line1.isEmpty else { return nil }
        return ContactAddress(
            name: contactNameFromAttributes(),
            email: attributes["email"] ?? "",
            addressLine1: line1,
            addressLine2: nonEmptyTrimmed(attributes["shippingaddress2"]),
            city: attributes["shippingcity"],
            state: attributes["shippingstate"],
            postalCode: attributes["shippingzipcode"],
            country: attributes["shippingcountry"]
        )
    }

    private func resolvedContactName(_ name: String) -> String {
        if let trimmed = nonEmptyTrimmed(name) {
            return trimmed
        }

        return contactNameFromAttributes()
    }

    private func contactNameFromAttributes() -> String {
        [attributes["firstname"], attributes["lastname"]]
            .compactMap(nonEmptyTrimmed)
            .joined(separator: " ")
    }

    private func nonEmptyTrimmed(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// Configures the host app’s custom URL scheme for built-in PayPal return/cancel deep links.
    /// - Returns: `false` if a non-empty scheme is malformed, or not listed under `CFBundleURLSchemes` in `Info.plist`
    ///   when ``PayPalRedirectURLSchemeValidator/shouldValidateAgainstInfoPlist`` is `true` (see that property for XCTest / sample-app **DEBUG** exceptions).
    @discardableResult
    func setBuiltInPayPalRedirectURLScheme(_ scheme: String?) -> Bool {
        RoktAPIHelper.logApiCalled(
            Self.apiSetPayPalRedirectSchemeCode,
            ["hasScheme": "\(scheme?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)"]
        )
        guard let scheme, !scheme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            builtInPayPalRedirectURLScheme = nil
            return true
        }
        let trimmed = scheme.trimmingCharacters(in: .whitespacesAndNewlines)
        guard PayPalRedirectURLSchemeValidator.isValidBareScheme(trimmed) else {
            RoktLogger.shared.error(
                "Rokt: built-in PayPal redirect URL scheme must be a bare scheme (no \"://\" or path segments)."
            )
            return false
        }
        if PayPalRedirectURLSchemeValidator.shouldValidateAgainstInfoPlist,
           !PayPalRedirectURLSchemeValidator.isSchemeRegistered(trimmed, in: .main) {
            RoktLogger.shared.error(
                "Rokt: URL scheme '\(trimmed)' is not registered under CFBundleURLSchemes in Info.plist."
            )
            return false
        }
        builtInPayPalRedirectURLScheme = trimmed
        return true
    }

    func setFrameworkType(_ frameworkType: RoktFrameworkType) {
        self.frameworkType = frameworkType
        logApiCallBuffered(Self.apiSetFrameworkTypeCode, ["frameworkType": frameworkType.toString])
    }

    // MARK: - Public API usage diagnostics

    /// Bounded, non-PII format guard for the mParticle public-API diagnostic codes forwarded by
    /// the Rokt kit. Accepts uppercase SNAKE_CASE identifiers only (e.g. `LOG_EVENT`), 1...40
    /// chars — which structurally excludes event/screen names, attribute values, URLs, and ids
    /// from ever reaching the `code` tag. Malformed codes are dropped by the caller.
    static func isValidMParticleApiCode(_ code: String) -> Bool {
        guard (1...40).contains(code.count), let first = code.first, ("A"..."Z").contains(first) else {
            return false
        }
        return code.allSatisfy { ("A"..."Z").contains($0) || ("0"..."9").contains($0) || $0 == "_" }
    }

    /// Log a public API call, buffering it until init when the SDK isn't initialised yet. This supports
    /// `globalEvents`, mParticle API forwarding, and configuration APIs that may run before init.
    func logApiCallBuffered(_ code: String, _ additionalInfo: [String: String] = [:]) {
        let shouldSend = pendingApiLogsLock.withLock {
            guard roktTagId == nil else { return true }
            // Bounded buffer — a wrapper spamming setFrameworkType pre-init must not grow it unbounded.
            guard pendingApiLogs.count < Self.maxPendingApiLogs else { return false }
            pendingApiLogs.append((code, additionalInfo))
            return false
        }
        if shouldSend {
            RoktAPIHelper.logApiCalled(code, additionalInfo)
        }
    }

    func setRoktTagIdAndDrainPendingApiLogs(
        _ roktTagId: String
    ) -> [(code: String, info: [String: String])] {
        pendingApiLogsLock.withLock {
            self.roktTagId = roktTagId
            let logs = pendingApiLogs
            pendingApiLogs.removeAll()
            return logs
        }
    }

    // Shows the widget on top the visible view controller
    private func showNow(payload: ExecutePayload) {
        guard isInitialized else {
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
                pageModel: layoutPage.pageModel,
                layoutPluginViewStates: layoutPage.cacheProperties?.pluginViewStates,
                defaultLayoutLoader: swiftUiExecuteLayout,
                config: roktConfig.getUXConfig(),
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
                pageModel: layoutPage.pageModel,
                layoutPluginViewStates: layoutPage.cacheProperties?.pluginViewStates,
                layoutLoaders: placements,
                config: roktConfig.getUXConfig(),
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

    func callOnRoktUXEvent(_ executeId: String,
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
                }, failureHandler: {
                    event.onError?(event.id, NSError(domain: Self.urlOpenErrorDomain,
                                                     code: Self.urlOpenErrorCode,
                                                     userInfo: [
                                                         NSLocalizedDescriptionKey: Self.urlOpenErrorDescription
                                                     ]))
                })
            }
        } else if (uxEvent as? RoktUXEvent.LayoutFailure) != nil {

            callOnRoktEvent(executeId, event: uxEvent.mapToRoktEvent)
            callOnUnLoad(executeId)
            placements = nil
            _swiftUiExecuteLayout = nil
        } else if (uxEvent as? RoktUXEvent.LayoutInteractive) != nil {
            // Track placement load (count gates clearCallBacks).
            callOnLoad(executeId)
            callOnRoktEvent(executeId, event: uxEvent.mapToRoktEvent)
        } else if (uxEvent as? RoktUXEvent.LayoutClosed) != nil
                    || (uxEvent as? RoktUXEvent.LayoutCompleted) != nil {
            // Track placement unload.
            callOnRoktEvent(executeId, event: uxEvent.mapToRoktEvent)
            callOnUnLoad(executeId)
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

            // Map PaymentProvider -> PaymentMethodType. Switching on the enum (not its
            // rawValue) makes a future schema rename a compile-time error rather than a
            // silent .default; @unknown default covers cases added in newer DcuiSchema versions.
            let paymentMethod: PaymentMethodType
            // PascalCase wire token for the cart `initialize-purchase` body's `paymentProvider`
            // field — pass-through of the upstream DcuiSchema `PaymentProvider` enum so backend
            // can disambiguate routing (e.g. Stripe-routed ApplePay vs built-in ApplePay).
            // Matches the web SDK payload on `INITIATE_DEVICE_PAY_EVENT`.
            let paymentProviderWireValue: String
            // Card schema and Stripe schema both map to PaymentMethodType.card today;
            // routes diverge in processPayment via builtInCardDevicePaySession (set only for `.card`).
            let isBuiltInCardForwarding = (event.paymentProvider == .card)
            switch event.paymentProvider {
            case .applePay:
                paymentMethod = .applePay
                paymentProviderWireValue = "ApplePay"
            case .stripe:
                paymentMethod = .card
                paymentProviderWireValue = "Stripe"
            case .afterpay:
                paymentMethod = .afterpay
                paymentProviderWireValue = "Afterpay"
            case .paypal:
                paymentMethod = .paypal
                paymentProviderWireValue = "PayPal"
            case .card:
                paymentMethod = .card
                paymentProviderWireValue = "Card"
            case .googlePay:
                RoktLogger.shared.error("GooglePay device-pay not supported on iOS")
                devicePayFinalized(executeId: executeId, layoutId: event.layoutId,
                                   catalogItemId: event.catalogItemId, success: false)
                return
            @unknown default:
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
            switch paymentMethod {
            case .afterpay, .paypal:
                let billing = buildContactAddress(from: event.transactionData?.billingAddress)
                    ?? buildContactAddressFromAttributes()
                let shipping = buildContactAddress(from: event.transactionData?.shippingAddress)
                    ?? buildContactAddressFromAttributes()
                let returnURL: String?
                let cancelURL: String?
                if paymentMethod == .paypal {
                    guard let scheme = builtInPayPalRedirectURLScheme else {
                        RoktLogger.shared.error(Self.builtInPayPalMissingRedirectSchemeMessage)
                        devicePayFinalized(executeId: executeId, layoutId: event.layoutId,
                                           catalogItemId: event.catalogItemId, success: false)
                        return
                    }
                    let urls = BuiltInPayPalRedirectURLs.returnAndCancelURLs(forBareScheme: scheme)
                    returnURL = urls.returnURL
                    cancelURL = urls.cancelURL
                } else {
                    returnURL = nil
                    cancelURL = nil
                }
                context = PaymentContext(
                    billingAddress: billing,
                    shippingAddress: shipping,
                    returnURL: returnURL,
                    cancelURL: cancelURL
                )
            case .card where isBuiltInCardForwarding:
                // Built-in card forwarding needs shipping/billing for /v1/cart/purchase but
                // no hosted-approval return/cancel URLs (Step-2 is a direct API call).
                let billing = buildContactAddress(from: event.transactionData?.billingAddress)
                    ?? buildContactAddressFromAttributes()
                let shipping = buildContactAddress(from: event.transactionData?.shippingAddress)
                    ?? buildContactAddressFromAttributes()
                context = PaymentContext(
                    billingAddress: billing,
                    shippingAddress: shipping,
                    returnURL: nil,
                    cancelURL: nil
                )
            default:
                context = PaymentContext()
            }

            // Find the topmost view controller for presenting the payment sheet
            guard let viewController = UIApplication.topViewController() else {
                RoktLogger.shared.error("No view controller available to present payment sheet")
                devicePayFinalized(executeId: executeId, layoutId: event.layoutId,
                                   catalogItemId: event.catalogItemId, success: false)
                return
            }

            let twoStepSessionFactory: (() -> BuiltInTwoStepDevicePaySession) = {
                BuiltInTwoStepDevicePaySession(
                    layoutId: event.layoutId,
                    catalogItemId: event.catalogItemId,
                    showConfirmation: { [weak self] layoutId, catalogItemId, catalogRuntimeData in
                        guard let self,
                              let state = self.stateManager.getState(id: executeId),
                              let ux = state.uxHelper as? RoktUX else { return }
                        ux.devicePayShowConfirmation(
                            layoutId: layoutId,
                            catalogItemId: catalogItemId,
                            catalogRuntimeData: catalogRuntimeData
                        )
                    }
                )
            }
            let paypalSession: BuiltInTwoStepDevicePaySession? = paymentMethod == .paypal
                ? twoStepSessionFactory()
                : nil
            let cardSession: BuiltInTwoStepDevicePaySession? = isBuiltInCardForwarding
                ? twoStepSessionFactory()
                : nil

            // Process the payment via the registered extension or built-in two-step flow
            paymentOrchestrator.processPayment(
                method: paymentMethod,
                paymentProvider: paymentProviderWireValue,
                item: item,
                context: context,
                cartItemId: event.cartItemId,
                from: viewController,
                builtInPayPalDevicePaySession: paypalSession,
                builtInCardDevicePaySession: cardSession
            ) { [weak self] result in
                self?.handleDevicePayPaymentCompletion(executeId: executeId, event: event, result: result)
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
                partnerPaymentReference: event.transactionData?.partnerPaymentReference
            ),
            fulfillmentDetails: fulfillmentDetails
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

    func handleDevicePayPaymentCompletion(executeId: String,
                                          event: RoktUXEvent.CartItemDevicePay,
                                          result: PaymentSheetResult) {
        switch result.outcome {
        case .succeeded:
            callOnRoktEvent(executeId, event: RoktEvent.CartItemInstantPurchase(
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
            devicePayFinalized(
                executeId: executeId,
                layoutId: event.layoutId,
                catalogItemId: event.catalogItemId,
                success: true
            )
        case .canceled:
            devicePayRetry(
                executeId: executeId,
                layoutId: event.layoutId,
                catalogItemId: event.catalogItemId
            )
        case .failed:
            callOnRoktEvent(executeId, event: RoktEvent.CartItemInstantPurchaseFailure(
                identifier: event.layoutId,
                catalogItemId: event.catalogItemId,
                cartItemId: event.cartItemId,
                error: result.errorMessage
            ))
            devicePayFinalized(
                executeId: executeId,
                layoutId: event.layoutId,
                catalogItemId: event.catalogItemId,
                success: false
            )
        @unknown default:
            callOnRoktEvent(executeId, event: RoktEvent.CartItemInstantPurchaseFailure(
                identifier: event.layoutId,
                catalogItemId: event.catalogItemId,
                cartItemId: event.cartItemId,
                error: result.errorMessage
            ))
            devicePayFinalized(
                executeId: executeId,
                layoutId: event.layoutId,
                catalogItemId: event.catalogItemId,
                success: false
            )
        }
    }

    func handleForwardPayment(executeId: String,
                              event: RoktUXEvent.CartItemForwardPayment) {
        let presentedPayPal = paymentOrchestrator.presentPendingBuiltInPayPalForForwardPayment { [weak self] result in
            guard let self else { return }
            switch result.outcome {
            case .succeeded:
                self.forwardPaymentFinalized(
                    executeId: executeId,
                    layoutId: event.layoutId,
                    catalogItemId: event.catalogItemId,
                    success: true,
                    failureReason: nil
                )
            case .canceled:
                self.forwardPaymentFinalized(
                    executeId: executeId,
                    layoutId: event.layoutId,
                    catalogItemId: event.catalogItemId,
                    success: false,
                    failureReason: "User cancelled PayPal checkout"
                )
            case .failed:
                self.forwardPaymentFinalized(
                    executeId: executeId,
                    layoutId: event.layoutId,
                    catalogItemId: event.catalogItemId,
                    success: false,
                    failureReason: result.errorMessage ?? Self.unknownForwardPaymentFailureReason
                )
            @unknown default:
                self.forwardPaymentFinalized(
                    executeId: executeId,
                    layoutId: event.layoutId,
                    catalogItemId: event.catalogItemId,
                    success: false,
                    failureReason: Self.unknownForwardPaymentFailureReason
                )
            }
        }
        if presentedPayPal {
            return
        }

        let forwardPaymentCartPurchase = ForwardPaymentCartPurchaseCoordinator(
            paymentOrchestrator: paymentOrchestrator,
            unknownFailureReason: Self.unknownForwardPaymentFailureReason,
            missingPriceFailureReason: Self.missingForwardPaymentPriceReason,
            resolveCartPurchaseFinalization: { RoktInternalImplementation.resolveForwardPaymentFinalization(from: $0) },
            resolveTransportFailureFinalization: {
            RoktInternalImplementation.resolveForwardPaymentFinalization(fromFailureMessage: $0) },
            emitRoktEvent: { [weak self] executeId, event in
                self?.callOnRoktEvent(executeId, event: event)
            },
            finalizeForwardPayment: { [weak self] executeId, layoutId, catalogItemId, success, failureReason in
                self?.forwardPaymentFinalized(
                    executeId: executeId,
                    layoutId: layoutId,
                    catalogItemId: catalogItemId,
                    success: success,
                    failureReason: failureReason
                )
            }
        )
        forwardPaymentCartPurchase.performForwardPaymentCartPurchase(
            executeId: executeId,
            event: event
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

    /// Ends a placement whose result was discarded because `clearSession` landed after it started. The failure is
    /// reported through the handler that placement started with, never the shared `roktEvent`: `isExecuting` is
    /// released before the fence is checked, so a placement started on another queue inside that window may already
    /// own `roktEvent` and `placements`, and it must neither receive this failure nor lose its state. Shared state is
    /// cleared only while it is still this placement's.
    private func concludeDiscarded(selectionId: String, onRoktEvent: (RoktEvent) -> Void) {
        onRoktEvent(RoktEvent.HideLoadingIndicator())
        onRoktEvent(RoktEvent.PlacementFailure(identifier: nil))
        if executingSelectionId == selectionId {
            clearCallBacks()
        }
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

    private func addGlobalEventListener(_ onEvent: @escaping (RoktEvent) -> Void) {
        globalEventListenersLock.lock()
        defer { globalEventListenersLock.unlock() }
        globalEventListeners.append(onEvent)
    }

    func removeAllGlobalEventListeners() {
        globalEventListenersLock.lock()
        defer { globalEventListenersLock.unlock() }
        globalEventListeners.removeAll()
    }

    private func sendEventToGlobalListeners(_ roktEvent: RoktEvent) {
        globalEventListenersLock.lock()
        let listeners = globalEventListeners
        globalEventListenersLock.unlock()
        listeners.forEach { $0(roktEvent) }
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

        let pendingApiLogs = setRoktTagIdAndDrainPendingApiLogs(roktTagId)
        sessionManager.storedTagId = roktTagId
        RoktAPIHelper.logApiCalled(mParticleKitDetails != nil ? Self.apiInitMParticleCode : Self.apiInitCode)
        pendingApiLogs.forEach { RoktAPIHelper.logApiCalled($0.code, $0.info) }
        isInitFailedForFont = false
        FontManager.resetFontRecoveryState()
        FontManager.resetDiskPressureState()
        stateManager = StateBagManager()

        RoktLogger.shared.debug("Starting API initialization request")
        initRecoveryAttempt = 0
        performInit(roktTagId: roktTagId, initStartTime: initStartTime)
    }

    private func performInit(roktTagId: String, initStartTime: Date) {
        let service = makeTxnInitServiceOverride?(roktTagId) ?? defaultTxnInitService(roktTagId: roktTagId)
        initGeneration += 1
        let generation = initGeneration
        Task {
            do {
                let result = try await service.initSession()
                let initResponse = result.response.toInitRespose(featureFlags: result.featureFlags)
                DispatchQueue.main.async {
                    guard self.initGeneration == generation else { return }
                    self.handleInitSuccess(initResponse, initStartTime: initStartTime)
                }
            } catch {
                let statusCode = Self.statusCode(from: error)
                DispatchQueue.main.async {
                    guard self.initGeneration == generation else { return }
                    self.handleInitFailure(
                        error: error,
                        statusCode: statusCode,
                        response: "",
                        initStartTime: initStartTime
                    )
                }
            }
        }
    }

    // Init completes on config; fonts load off the critical path (never block/fail init).
    private func handleInitSuccess(_ initResponse: InitRespose, initStartTime: Date) {
        RoktLogger.shared.info("API initialization succeeded")
        self.isInitialized = true
        self.initRecoveryAttempt = 0
        self.initFeatureFlags = initResponse.featureFlags

        self.processedTimingsRequests = TimingsRequestProcessor()
        self.processedTimingsRequests?.setInitStartTime(initStartTime)

        self.clientTimeoutMilliseconds = initResponse.timeout != 0 ?
        initResponse.timeout : self.clientTimeoutMilliseconds
        self.defaultLaunchDelayMilliseconds = initResponse.delay != 0 ?
        initResponse.delay : self.defaultLaunchDelayMilliseconds
        NetworkingHelper.updateTimeout(timeout: self.clientTimeoutMilliseconds/1000)
        self.processedTimingsRequests?.setInitEndTime()

        RoktLogger.shared.info("Initialization complete - success: \(self.isInitialized)")
        self.sendEventToGlobalListeners(RoktEvent.InitComplete(success: self.isInitialized))

        // Replay any execute that arrived before init finished.
        if let page = pendingPayload {
            showNow(payload: page)
        }

        // Replay event batches that failed to send in a previous session.
        replayPendingTxnEvents()

        let initFonts = initResponse.fonts
        FontManager.removeUnusedFonts(fonts: initFonts)
        RoktAPIHelper.downloadFonts(initFonts) {
            RoktLogger.shared.debug("Font download complete")
        }
    }

    private func handleInitFailure(error: Error, statusCode: Int?, response: String, initStartTime: Date) {
        RoktLogger.shared.error("Initialization failed - statusCode: \(statusCode ?? -1), " +
                                "error: \(error.localizedDescription)")
        self.isInitialized = false
        self.processedTimingsRequests?.setInitEndTime()
        NetworkingHelper.updateTimeout(timeout: self.clientTimeoutMilliseconds/1000)
        // Don't report diagnostics for 429 (Too Many Requests) status code
        if let code = statusCode, code != Self.rateLimitedStatusCode {
            self.sendDiagnostics(Self.initDiagnosticCode, error: error, statusCode: statusCode, response: response)
        }
        self.sendEventToGlobalListeners(RoktEvent.InitComplete(success: false))
        self.scheduleInitRecovery(error: error, statusCode: statusCode, initStartTime: initStartTime)
    }

    private func scheduleInitRecovery(error: Error, statusCode: Int?, initStartTime: Date) {
        guard let roktTagId,
              Self.isRecoverable(error: error, statusCode: statusCode),
              initRecoveryAttempt < Self.initRecoveryDelaysSeconds.count else { return }

        let delay = Self.initRecoveryDelaysSeconds[initRecoveryAttempt]
        let attempt = initRecoveryAttempt + 1
        initRecoveryAttempt = attempt
        let generation = initGeneration

        RoktLogger.shared.info("Scheduling init recovery attempt \(attempt) in \(delay)s")
        initRecoveryScheduler(delay) { [weak self] in
            guard let self, self.initGeneration == generation, !self.isInitialized else { return }
            self.performInit(roktTagId: roktTagId, initStartTime: initStartTime)
        }
    }

    // A wrong tag id or a rejected request will fail the same way every time, so only
    // rate limiting, server faults and transient transport failures are worth coming back for.
    // Recovery is scheduled seconds later rather than sent inline, so an offline device is
    // worth retrying here even though the in-request loops fail fast on it.
    private static func isRecoverable(error: Error, statusCode: Int?) -> Bool {
        if let statusCode {
            return statusCode == rateLimitedStatusCode || (500..<600).contains(statusCode)
        }
        return NetworkRetryRules.isTransientTransportFailure(error, policy: .transientIncludingOffline)
    }

    private func defaultTxnInitService(roktTagId: String) -> TxnInitService {
        // Mock transports are a development-only convenience (Environment.Mock) and
        // are compiled out of release builds to keep them off the shipped SDK.
        var httpClient: HTTPClientAdapter = NetworkingHelper.shared.httpClient
        #if DEBUG
        if config.environment == .Mock { httpClient = MockTxnInitHTTPClient() }
        #endif
        return TxnInitService(
            environment: config.environment,
            accountId: roktTagId,
            sdkVersion: libraryVersion,
            layoutSchemaVersion: Self.txnLayoutSchemaVersion,
            httpClient: httpClient,
            deviceHeaders: NetworkingHelper.txnDeviceHeaders()
        )
    }

    // `generation` is the session generation the placement started in; the response's echoed
    // events are kept only while it is still current (the session roll-forward is fenced by the
    // store's own epoch).
    func defaultOffersService(roktTagId: String, generation: Int) -> OffersService {
        var httpClient: HTTPClientAdapter = NetworkingHelper.shared.httpClient
        #if DEBUG
        if config.environment == .Mock { httpClient = MockOffersHTTPClient() }
        #endif
        return OffersService(
            environment: config.environment,
            accountId: roktTagId,
            sdkVersion: libraryVersion,
            layoutSchemaVersion: Self.txnLayoutSchemaVersion,
            sessionManager: TxnSessionManager(roktTagId: roktTagId, store: txnSessionStore),
            httpClient: httpClient,
            deviceHeaders: NetworkingHelper.txnDeviceHeaders(),
            captureEvents: { [weak self] events in
                self?.captureUntriggeredEvents(events, generation: generation)
            }
        )
    }

    private static func statusCode(from error: Error) -> Int? {
        if case TxnInitService.TxnInitError.unexpectedStatusCode(let code) = error {
            return code
        }
        return nil
    }

    // Each batch gets a fresh service instance so it rehydrates the latest persisted token.
    // A batch names the session that produced it; when that session is no longer the live one
    // (cleared, or replaced by a later placement) the batch is replayed on its own session
    // instead of riding the live token. Without an origin the batch follows the live session.
    func dispatchTxnEvents(_ events: [TxnEvent], originSessionId: String? = nil) {
        guard !events.isEmpty, let roktTagId else { return }
        let service = makeTxnEventServiceOverride?(roktTagId) ?? defaultTxnEventService(roktTagId: roktTagId)
        Task {
            if let originSessionId, !originSessionId.isEmpty,
               await service.sessionManager.currentSessionId != originSessionId {
                try? await service.replay(events: events, sessionId: originSessionId)
            } else {
                try? await service.send(events: events)
            }
        }
    }

    // Replays event batches that failed to send in a previous session (offline / rate-limited),
    // dropping any past their 30-minute TTL. Called once init succeeds.
    // Each batch is replayed against the session that produced it, not the current one.
    func replayPendingTxnEvents() {
        guard let roktTagId else { return }
        for batch in txnPendingEventStore.drainValid() {
            guard let sessionId = batch.sessionId else {
                // Predates session binding; replaying would attach it to the live session.
                RoktLogger.shared.debug(
                    "Dropping \(batch.events.count) pending event(s) with no session binding"
                )
                continue
            }
            replayBatch(events: batch.events, sessionId: sessionId)
        }
    }

    /// Replays one bound batch. Split out so tests can observe which session each batch is
    /// replayed against without standing up the network stack.
    func replayBatch(events: [TxnEvent], sessionId: String) {
        guard let roktTagId else { return }
        let service = makeTxnEventServiceOverride?(roktTagId) ?? defaultTxnEventService(roktTagId: roktTagId)
        Task { try? await service.replay(events: events, sessionId: sessionId) }
    }

    /// Ends the current Rokt session so the next placement starts a new one.
    ///
    /// Order matters: flushing first hands buffered events to a `TxnEventService` that captures
    /// the departing token as it is built, so they stay attributed to the customer leaving. Only
    /// then is the session wiped, synchronously, so the next placement cannot rehydrate it — and
    /// under the generation lock, together with the generation, so a placement that reads either
    /// one after this reset reads both after it.
    func clearSession() {
        RoktAPIHelper.logApiCalled(Self.apiClearSessionCode)
        EventQueue.flush()
        // The generation moves first and the store clears under the same lock, so a capture from a
        // placement still in flight either lands before the clear or is fenced out — never after it.
        sessionGenerationLock.lock()
        sessionGeneration &+= 1
        // The persisted session and its epoch go under the same lock as the generation. A placement builds its
        // offers service under this lock too, so the session manager it carries can never read the old epoch
        // against a new generation, or the new epoch against an old one; and it hands its request to the network
        // stack under this lock (handOffIfCurrent), so no request leaves for a session this call has ended.
        TxnSessionManager.clearPersistedSession(store: txnSessionStore)
        // Also clears the legacy session id and, via ManagedSession, the real-time event store.
        sessionManager.invalidateSession()
        // The cached experience was fetched inside the dropped session, so it goes with it. Under the same lock,
        // so a response commit in progress finishes first and what it wrote is what this clear removes.
        ExperienceCacheManager.clearCache()
        mustBypassCacheOnNextExecute = true
        sessionGenerationLock.unlock()
        RoktLogger.shared.info("Session cleared; the next placement will start a new session")
    }

    func currentSessionGeneration() -> Int {
        sessionGenerationLock.lock()
        defer { sessionGenerationLock.unlock() }
        return sessionGeneration
    }

    /// The state a placement starts from, read in one hold of the generation lock: the generation its commits
    /// are checked against, and whether it must bypass the cache. Read as two separate values, a clearSession
    /// on another queue could land between them and hand the placement the new generation with the bypass
    /// still off — and the cache read is a direct file read, so the departing customer's experience would be
    /// served and every later generation check would accept it as current.
    private func placementStart() -> (generation: Int, bypassCache: Bool) {
        sessionGenerationLock.lock()
        defer { sessionGenerationLock.unlock() }
        let generation = sessionGeneration
        unitTest_duringPlacementStart?()
        return (generation, mustBypassCacheOnNextExecute)
    }

    /// Runs `commit` under the generation lock while `generation` is still current and returns true; returns
    /// false, running nothing, once clearSession has moved the generation. A clearSession arriving on another
    /// queue waits for a commit in progress, so a response is committed whole or not at all — never half of it.
    /// The commit parses the experience and reads the plugin view-state files under the lock, so that wait is
    /// bounded by one experience's parse — tens of milliseconds on a device — and never by network: nothing
    /// under this lock waits on a request. Keep it that way; a longer hold here is a longer stall for the host's
    /// clearSession call.
    func commitIfCurrent(generation: Int, _ commit: () -> Void) -> Bool {
        sessionGenerationLock.lock()
        defer { sessionGenerationLock.unlock() }
        guard sessionGeneration == generation else { return false }
        commit()
        return true
    }

    /// Runs `handOff` under the generation lock while `generation` is still current and returns true; returns false,
    /// running nothing, once clearSession has moved the generation. The hand-off is the one call that gives a
    /// placement's offers request to the network stack: a synchronous enqueue (the URLRequest is built and a
    /// URLSession task is resumed) that returns as soon as the request is queued and never waits on its response.
    /// Held there, the lock makes the decision to send and the send itself one step: a clearSession on another queue
    /// lands wholly before it, and nothing is sent for the departing customer, or wholly after it, when the request is
    /// already queued and cannot be recalled. Its response is then fenced out: commitIfCurrent refuses the render and
    /// the cache write, the store's epoch refuses the session it carries (TxnSessionManager.update), and
    /// captureUntriggeredEvents drops its echoed events, so nothing from it is shown or persisted. The hold is bounded
    /// by that enqueue, never by the network; keep it that way.
    func handOffIfCurrent(generation: Int, _ handOff: () -> Void) -> Bool {
        commitIfCurrent(generation: generation, handOff)
    }

    // The offers response echoes events for the next placement to forward. Captured after a
    // clearSession, they would re-seed the store that call just emptied.
    func captureUntriggeredEvents(_ events: [UntriggeredRealTimeEvent], generation: Int) {
        // Checked and written under the generation lock, so a clearSession cannot slip between them.
        sessionGenerationLock.lock()
        defer { sessionGenerationLock.unlock() }
        guard sessionGeneration == generation else { return }
        RealTimeEventManager.shared.addUntriggeredEvents(events)
    }

    private func defaultTxnEventService(roktTagId: String) -> TxnEventService {
        var httpClient: HTTPClientAdapter = NetworkingHelper.shared.httpClient
        #if DEBUG
        if config.environment == .Mock { httpClient = MockTxnInitHTTPClient() }
        #endif
        return TxnEventService(
            environment: config.environment,
            accountId: roktTagId,
            sdkVersion: libraryVersion,
            sessionManager: TxnSessionManager(roktTagId: roktTagId, store: txnSessionStore),
            httpClient: httpClient,
            deviceHeaders: NetworkingHelper.txnDeviceHeaders(),
            pendingStore: txnPendingEventStore
        )
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
        }

        if attributes[keyAdsExperienceType] == valueAdsExperienceShoppable {
            guard validateShoppableAdsFeatureFlag(identifier: viewName, onFailure: composedEventHandler),
                  validateShoppableAdsPaymentExtension(identifier: viewName, onFailure: composedEventHandler) else {
                return
            }
        }

        isExecuting = true
        // The generation and the cache bypass are one reading under the generation lock (see placementStart), so
        // a clearSession on another queue lands wholly before or wholly after this placement's start. The bypass is
        // latched once per execute: both cache reads in it — the experience response and the view state read later
        // in processLayoutPageExecutePayload — must see the same answer. Disarmed only when an execute fetches a
        // fresh experience, so a failed placement keeps the next one off the cache.
        let start = placementStart()
        let generation = start.generation
        cacheSuppressedForCurrentExecute = start.bypassCache
        // The session the placement started in — a failure discarded after clearSession is reported against it.
        let departingSessionId = sessionManager.getCurrentSessionIdWithoutExpiring()
        // Stamped before the state it guards, so a discarded placement that reads this id leaves that state alone.
        executingSelectionId = selectionId
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

                    if self.shouldReadFromCache(),
                       let cachedExperience = ExperienceCacheManager.getCachedExperienceResponse(
                           viewName: viewName,
                           attributes: cacheAttributes,
                           cacheDuration: self.roktConfig.cacheConfig.cacheDuration
                       ) {
                        self.unitTest_beforeCacheHitCommit?()
                        onExperiencesRequestEnd()
                        self.isExecuting = false

                        // A cached experience is committed — legacy session id, echoed events — under the same fence
                        // as a network response, and re-checked before the render: a clearSession since the
                        // placement started discards it whole.
                        var layoutPageExecutePayload: LayoutPageExecutePayload?
                        let committed = self.commitIfCurrent(generation: generation) {
                            layoutPageExecutePayload = self.processLayoutPageExecutePayload(
                                cachedExperience, selectionId: selectionId, viewName: viewName, attributes: attributes
                            )
                        }
                        guard committed else {
                            RoktLogger.shared.info("Discarding a cached placement that resolved after clearSession")
                            self.concludeDiscarded(selectionId: selectionId, onRoktEvent: composedEventHandler)
                            return
                        }
                        guard let layoutPageExecutePayload else {
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

                        self.unitTest_afterCacheHitCommit?()
                        guard self.currentSessionGeneration() == generation else {
                            RoktLogger.shared.info("Discarding a cached placement that resolved after clearSession")
                            self.concludeDiscarded(selectionId: selectionId, onRoktEvent: composedEventHandler)
                            return
                        }

                        let payload = ExecutePayload(layoutPage: layoutPageExecutePayload,
                                                     startDate: startDate,
                                                     selectionId: selectionId)
                        self.show(payload)
                    } else {
                        let onSuccess: (String?) -> Void = { page in
                            onExperiencesRequestEnd()
                            // Released before the fence so a discarded completion cannot wedge execute.
                            self.isExecuting = false

                            // The response is committed — cache write, legacy session id, echoed events — only while
                            // the placement's generation is current, and under the generation lock: a clearSession on
                            // another queue either waits for the whole commit or fences it out, never half of it.
                            var layoutPageExecutePayload: LayoutPageExecutePayload?
                            let committed = self.commitIfCurrent(generation: generation) {
                                guard let page else { return }
                                self.mustBypassCacheOnNextExecute = false
                                // cache experience if applicable
                                if self.isCacheEnabledAndConfigured() {
                                    let cacheAttributes = self.roktConfig.cacheConfig.getCacheAttributesOrFallback(attributes)
                                    ExperienceCacheManager.cacheExperienceResponse(
                                        viewName: viewName,
                                        attributes: cacheAttributes,
                                        experienceResponse: page,
                                        success: {
                                            // The store writes on its own queue, so a clearSession that ran after
                                            // this commit may have cleared before the write landed: clear again.
                                            // The whole cache goes, not one entry: every write is already preceded
                                            // by a full clear (the cache holds one experience), the next session's
                                            // own write would share this key, and a fresh experience cleared this
                                            // way costs the new session one refetch — never a wrong experience.
                                            if self.currentSessionGeneration() != generation {
                                                ExperienceCacheManager.clearCache()
                                            }
                                        }
                                    )
                                }

                                // Use cacheAttributes for plugin view states if cache is enabled for consistency
                                let attributesForPluginStates = self.roktConfig.cacheConfig
                                    .getCacheAttributesOrFallback(attributes)
                                layoutPageExecutePayload = self.processLayoutPageExecutePayload(
                                    page, selectionId: selectionId, viewName: viewName, attributes: attributesForPluginStates
                                )
                            }
                            guard committed else {
                                RoktLogger.shared.info("Discarding a placement that completed after clearSession")
                                self.concludeDiscarded(selectionId: selectionId, onRoktEvent: composedEventHandler)
                                return
                            }
                            guard let layoutPageExecutePayload else {
                                self.conclude(withFailure: true)
                                return
                            }
                            // A clearSession that landed after the commit owns the screen now; the commit's state
                            // went with it under the lock. (One landing during the render itself is the residual.)
                            guard self.currentSessionGeneration() == generation else {
                                RoktLogger.shared.info("Discarding a placement that completed after clearSession")
                                self.concludeDiscarded(selectionId: selectionId, onRoktEvent: composedEventHandler)
                                return
                            }

                            let payload = ExecutePayload(
                                layoutPage: layoutPageExecutePayload,
                                startDate: startDate,
                                selectionId: selectionId
                            )
                            self.show(payload)
                        }
                        let onFailure: (Error, Int?, String) -> Void = { error, statusCode, response in
                            onExperiencesRequestEnd()
                            guard self.currentSessionGeneration() == generation else {
                                // Not executeFailureHandler: its diagnostic would carry the new session.
                                // The failure is still reported, against the session it happened in.
                                self.isExecuting = false
                                if let code = statusCode, code != 429 {
                                    RoktAPIHelper.sendDiagnostics(
                                        message: Self.executeDiagnosticCode,
                                        callStack: "response: \(response) ,statusCode: \(String(describing: statusCode))"
                                            + " ,error: \(error.localizedDescription) ,discardedAfterClearSession: true",
                                        sessionId: departingSessionId
                                    )
                                }
                                if case OffersService.OffersError.discardedBeforeSend = error {
                                    RoktLogger.shared.info(
                                        "Discarding a placement that was reset before its offers request was sent"
                                    )
                                } else {
                                    RoktLogger.shared.info("Discarding a placement that failed after clearSession")
                                }
                                self.concludeDiscarded(selectionId: selectionId, onRoktEvent: composedEventHandler)
                                return
                            }
                            self.executeFailureHandler(error, statusCode, response)
                        }

                        // pageInit timing travels in attributes; record it here since the offers service
                        // doesn't own timing extraction.
                        if let pageInitAttr = RoktAPIHelper.getPageInitData(attributes: attributes),
                           let validPageInitTime = self.processedTimingsRequests?.getValidPageInitTime(
                               selectionId: selectionId,
                               timeAsString: pageInitAttr
                           ) {
                            self.processedTimingsRequests?.setPageInitTime(
                                selectionId: selectionId,
                                time: validPageInitTime
                            )
                        }
                        self.unitTest_beforeOffersServiceBuilt?()
                        // The service, and the session manager it carries (which reads the store's epoch as it is
                        // built), is created only while the placement's generation is still current, under the
                        // generation lock. Once a clearSession has landed, no request is sent for this placement:
                        // the session the server would mint for the departing customer's attributes must never be
                        // written for the next customer to restore.
                        var builtOffersService: OffersService?
                        let started = self.commitIfCurrent(generation: generation) {
                            builtOffersService = self.makeOffersServiceOverride?(tagId)
                                ?? self.defaultOffersService(roktTagId: tagId, generation: generation)
                        }
                        guard started, let offersService = builtOffersService else {
                            self.isExecuting = false
                            RoktLogger.shared.info("Discarding a placement that was reset before its offers request was sent")
                            self.concludeDiscarded(selectionId: selectionId, onRoktEvent: composedEventHandler)
                            return
                        }
                        // The send runs on its own task after the lock above is released, so the generation is checked
                        // again there, at the one point that matters: the hand-off of the request to the network stack,
                        // for the first attempt and every retry, runs under the generation lock and only while the
                        // generation is still current. A clearSession lands wholly before that hand-off (nothing is
                        // sent, and the failure comes back as `discardedBeforeSend` and takes the discard branch of
                        // `onFailure`) or wholly after it, when the fences above discard the response.
                        offersService.getExperienceData(
                            viewName: viewName,
                            attributes: attributes,
                            config: self.roktConfig,
                            onRequestStart: onExperiencesRequestStart,
                            sendGate: { [weak self] handOff in
                                self?.handOffIfCurrent(generation: generation, handOff) ?? false
                            },
                            successLayout: onSuccess,
                            failure: onFailure
                        )
                    }
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

    /// Gate for *reading* the experience cache; writes are unaffected.
    ///
    /// `clearSession()` empties the cache asynchronously, but this read is a direct synchronous
    /// file read — so the flag is what makes every placement after a reset deterministically
    /// reach the network until one of them has fetched a fresh experience.
    private func shouldReadFromCache() -> Bool {
        !cacheSuppressedForCurrentExecute && isCacheEnabledAndConfigured()
    }

    func processLayoutPageExecutePayload(_ page: String,
                                         selectionId: String,
                                         viewName: String? = nil,
                                         attributes: [String: String]) -> LayoutPageExecutePayload? {
        guard let pageData = page.data(using: .utf8) else {
            return nil
        }

        // Single parse: the UX helper decodes the experience response once and reports
        // the parse window; the resulting page model is reused for rendering.
        guard let parseResult = RoktUX.parseExperience(page) else {
            return nil
        }
        sessionManager.updateSessionId(newSessionId: parseResult.sessionId)

        processedTimingsRequests?.setExperienceJsonParseTimes(
            selectionId: selectionId,
            start: parseResult.parseStart,
            end: parseResult.parseEnd
        )

        guard let pageModel = parseResult.pageModel else {
            return nil
        }
        let events = try? decodeOnSeparateThread(UntriggeredEventsContainer.self, pageData)
        if let events = events {
            RealTimeEventManager.shared.addUntriggeredEvents(events.untriggeredEvents)
        }

        processedTimingsRequests?.setPageProperties(
            selectionId: selectionId,
            sessionId: parseResult.sessionId,
            pageId: pageModel.pageId,
            pageInstanceGuid: pageModel.pageInstanceGuid
        )

        if shouldReadFromCache() {
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
                experienceCacheAttributes: cacheAttributes,
                pluginViewStates: pluginViewStates,
                onPluginViewStateChange: onPluginViewStateChange
            )
            return LayoutPageExecutePayload(pageModel: pageModel,
                                            cacheProperties: cacheProperties)
        } else {
            // No cache: scope event de-duplication to this execute. The cache branch above
            // seeds `sentEventHashes` per view; without a reset here the set is only ever
            // (re)initialised on the cache path, so for non-cached executes it accumulates
            // hashes for the whole process lifetime — growing unbounded and, when an event
            // hash repeats across executes (e.g. a reused session id), silently dropping
            // events that were already "sent" by an earlier, unrelated execute.
            sentEventHashes = ThreadSafeSet()
            return LayoutPageExecutePayload(pageModel: pageModel,
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
        RoktAPIHelper.logApiCalled(Self.apiLayoutCode, [
            "hasConfig": "\(config != nil)",
            "colorMode": config?.colorModeDiagnosticValue ?? "none",
            "cacheEnabled": "\(config?.cacheConfig.isCacheEnabled() == true)",
            "attributeCount": "\(attributes.count)"
        ])
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
            if let onEvent {
                addGlobalEventListener(onEvent)
            } else {
                removeAllGlobalEventListeners()
            }
        } else {
            roktEventMap[viewName] = onEvent
        }
    }

    /// Default local TTL when a partner handoff omits expiry or supplies a past `expiresAt`
    /// (aligned with Web's rolling 30-minute transactions token window).
    private static let partnerSessionTokenDefaultTTL: TimeInterval = 30 * 60

    func setSession(_ session: RoktSession) {
        guard let roktTagId,
              !session.sessionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !session.sessionToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            RoktLogger.shared.warning(
                "Rokt.setSession ignored: SDK must be initialized and sessionId/sessionToken must be non-empty."
            )
            return
        }

        let expiresAtMs = Self.resolvedPartnerExpiresAtMilliseconds(session.expiresAt?.int64Value)
        let sessionToken = TxnSessionToken(token: session.sessionToken, expiresAt: expiresAtMs)
        TxnSessionPersistence.seed(
            roktTagId: roktTagId,
            sessionId: session.sessionId,
            sessionToken: sessionToken
        )
        sessionManager.updateSessionId(newSessionId: session.sessionId)
    }

    func getSession() -> RoktSession? {
        guard let roktTagId else {
            RoktLogger.shared.warning(
                "Rokt.getSession returned nil: SDK must be initialized."
            )
            return nil
        }

        let store = UserDefaultsTxnSessionStore()
        guard TxnSessionPersistence.isBound(to: roktTagId, store: store) else {
            RoktLogger.shared.warning(
                "Rokt.getSession returned nil: no session is present."
            )
            return nil
        }

        let snapshot = TxnSessionPersistence.readRaw(store: store)
        guard let sessionId = snapshot.sessionId,
              !sessionId.isEmpty,
              let token = snapshot.token,
              !token.isEmpty,
              let expiresAt = snapshot.expiresAt
        else {
            RoktLogger.shared.warning(
                "Rokt.getSession returned nil: no session is present."
            )
            return nil
        }

        if TxnSessionPersistence.clearIfExpired(expiresAt: expiresAt, store: store, clock: Date.init) {
            RoktLogger.shared.warning(
                "Rokt.getSession returned nil: session token is expired."
            )
            return nil
        }

        let expiresAtMs = Int64((expiresAt.timeIntervalSince1970 * 1000).rounded(.down))
        return RoktSession(
            sessionId: sessionId,
            sessionToken: token,
            expiresAtMilliseconds: expiresAtMs
        )
    }

    /// Uses a future partner-supplied expiry when present; otherwise (or when already past)
    /// falls back to now + ``partnerSessionTokenDefaultTTL``.
    private static func resolvedPartnerExpiresAtMilliseconds(
        _ expiresAtMilliseconds: Int64?,
        now: Date = Date()
    ) -> Int64 {
        let defaultMs = Int64(
            now.addingTimeInterval(partnerSessionTokenDefaultTTL).timeIntervalSince1970 * 1000
        )
        guard let expiresAtMilliseconds else {
            return defaultMs
        }
        let expiresAt = Date(timeIntervalSince1970: TimeInterval(expiresAtMilliseconds)/1000)
        if TxnSessionPersistence.isExpired(expiresAt: expiresAt, clock: { now }) {
            return defaultMs
        }
        return expiresAtMilliseconds
    }

    func setSessionId(sessionId: String) {
        guard !sessionId.isEmpty else {
            return
        }
        RoktAPIHelper.logApiCalled(Self.apiSetSessionIdCode)
        sessionManager.updateSessionId(newSessionId: sessionId)
    }

    func getSessionId() -> String? {
        let sessionId = sessionManager.getCurrentSessionIdWithoutExpiring()
        RoktAPIHelper.logApiCalled(Self.apiGetSessionIdCode, ["hasSession": "\(sessionId != nil)"])
        return sessionId
    }

    // MARK: - Payment Extension

    /// Register a payment extension for Shoppable Ads.
    func registerPaymentExtension(_ paymentExtension: PaymentExtension, config: [String: String]) {
        RoktAPIHelper.logApiCalled(Self.apiRegisterPaymentExtensionCode, ["hasConfig": "\(!config.isEmpty)"])
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
        let handled = paymentOrchestrator.handleURLCallback(with: url)
        RoktAPIHelper.logApiCalled(Self.apiHandleURLCallbackCode, ["handled": "\(handled)"])
        return handled
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
        RoktAPIHelper.logApiCalled(Self.apiSelectShoppableAdsCode, [
            "hasConfig": "\(config != nil)",
            "colorMode": config?.colorModeDiagnosticValue ?? "none",
            "cacheEnabled": "\(config?.cacheConfig.isCacheEnabled() == true)",
            "attributeCount": "\(attributes.count)"
        ])
        if isInitialized && !validateShoppableAdsFeatureFlag(identifier: identifier, onFailure: onRoktEvent) { return }
        guard validateShoppableAdsPaymentExtension(identifier: identifier, onFailure: onRoktEvent) else { return }

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

    private func validateShoppableAdsFeatureFlag(identifier: String?, onFailure: ((RoktEvent) -> Void)?) -> Bool {
        guard initFeatureFlags.isShoppableAdsEnabled() else {
            RoktLogger.shared.verbose(
                "Rokt: Shoppable Ads feature flags are disabled for this account."
            )
            onFailure?(RoktEvent.PlacementFailure(identifier: identifier))
            return false
        }
        return true
    }

    private func validateShoppableAdsPaymentExtension(identifier: String?, onFailure: ((RoktEvent) -> Void)?) -> Bool {
        guard paymentOrchestrator.hasRegisteredExtension else {
            RoktLogger.shared.error(
                "Rokt: No PaymentExtension registered. Call registerPaymentExtension() before using Shoppable Ads."
            )
            onFailure?(RoktEvent.PlacementFailure(identifier: identifier))
            return false
        }
        return true
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
    /// Pre-parsed experience page model; rendering reuses it so the
    /// experience response is decoded exactly once.
    let pageModel: RoktUXPageModel
    let cacheProperties: LayoutPageCacheProperties?
}

struct LayoutPageCacheProperties {
    let viewName: String?
    // Snapshot aligned with cache-attribute keys for this execute (see getCacheAttributesOrFallback).
    let experienceCacheAttributes: [String: String]
    let pluginViewStates: [RoktPluginViewState]?
    let onPluginViewStateChange: ((RoktPluginViewState) -> Void)?
}
