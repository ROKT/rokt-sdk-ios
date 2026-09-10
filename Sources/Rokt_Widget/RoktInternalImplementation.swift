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
    // Test-only hook, run while a placement is being admitted under the generation lock, after its starting state is
    // read and before it is stamped as the owner of the shared render state; nil in production.
    var unitTest_duringPlacementStart: (() -> Void)?
    // Test-only hook, run before a placement's offers service is built and its generation re-checked; nil in production.
    var unitTest_beforeOffersServiceBuilt: (() -> Void)?
    // Test-only hook, run once a placement's experience is committed and before what it decoded to is checked; nil in
    // production.
    var unitTest_afterCommitBeforePayloadCheck: (() -> Void)?
    // Test-only hook, run while a placement's render is being claimed under the generation lock, after the check has
    // passed and before the render's inputs are taken; nil in production.
    var unitTest_duringRenderClaim: (() -> Void)?
    // Test-only hook, run while a placement's shared callbacks are cleared under the generation lock, after the
    // ownership comparison has passed and before the clear; nil in production.
    var unitTest_duringCallbackClear: (() -> Void)?
    // Test-only hook, run while a response's echoed events are captured under the generation lock, after the generation
    // check has passed and before the store's write is queued; nil in production.
    var unitTest_duringEventCapture: (() -> Void)?
    // Test-only hook, run at the end of a response's prepare OUTSIDE the generation lock (prepareLayoutPageExecutePayload):
    // after its experience is parsed and, when the parse yields a page, after its echoed events are decoded and its cached
    // view state read; before any of it is committed. Nil in production.
    var unitTest_duringPayloadPrepare: (() -> Void)?
    // Test-only hook, run when a placement is ended with a failure through its own handler (concludeFailed): its result
    // discarded after clearSession, its experience decoded to nothing, or its offers request failed. A layout the
    // renderer fails does not run it; that failure reaches the host through the renderer's own event path. Nil in
    // production.
    var unitTest_duringPlacementFailure: (() -> Void)?
    private var pendingPayload: ExecutePayload?
    private var clientTimeoutMilliseconds: Double = RoktInternalImplementation.defaultTimeoutMilliseconds
    private var defaultLaunchDelayMilliseconds: Double = RoktInternalImplementation.defaultDelay
    private var isExecuting = false
    private var placements: [String: RoktEmbeddedView]?
    // The selection id of the placement that currently owns the shared render state: `roktEvent`, `placements` and
    // `_swiftUiExecuteLayout`. Stamped in admitPlacement and compared in claimRenderIfCurrent and clearCallBacks(ownedBy:),
    // always under the generation lock: a render is handed only the placement's own inputs, and a placement whose result
    // is discarded clears that state only while it is still its own.
    private var executingSelectionId: String?

    // Bumped by clearSession and captured when an execute starts; a completion from an earlier
    // generation is discarded. Covers what the txn store's epoch does not: the legacy session id,
    // the real-time event store, the experience cache and the render itself.
    private var sessionGeneration = 0
    // Recursive so a managed session invalidated under the lock may read the generation. Held only for bounded local
    // work: clearSession's own reset, a placement's admission (admitPlacement), the commit of a prepared response
    // (commitIfCurrent around commitLayoutPageExecutePayload: the legacy session id, the sent-event hashes, the timings
    // bookkeeping, and the queuing of the echoed events' write, of any new plugin view-state file and of the experience
    // cache's write), the build of a placement's offers service before its request is sent (commitIfCurrent in execute:
    // in-memory construction, plus the session manager's read of the session store's epoch), the synchronous hand-off of
    // one offers request, already built, to the network stack (handOffIfCurrent: the task's creation and resume), the
    // check-and-queue of a response's echoed events (captureUntriggeredEvents), the claim of a render's inputs
    // (claimRenderIfCurrent) and the compare-and-clear of the shared callbacks (clearCallBacks(ownedBy:)) — never a
    // callback into the host, never across the network, never a file read or write, never a parse, decode or encode,
    // never a wait on another thread. Everything proportional to a response's size — its parse, the decode of its echoed
    // events on the helper thread, the direct reads of the cached view-state files — runs before the lock is taken
    // (prepareLayoutPageExecutePayload), and so does everything proportional to a request's — its URL, its headers and
    // the JSON encoding of its body, which grows with the partner's attributes (OffersClient.fetchOffers) — so a
    // clearSession on another thread waits for none of it. Every file write made under the lock is queued on the
    // real-time event store's or the experience cache's own serial queue and runs there, after the lock is released.
    // Queuing under the lock is what orders those writes against clearSession, which queues the store's clear and the
    // cache's clear under the same lock: an accepted write always lands before a later clear, and a commit the lock
    // refuses queues nothing.
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
                    selectionId: payload.selectionId,
                    claim: payload.claim)
        }
    }

    // Renders on the inputs claimed for this placement under the generation lock (claimRenderIfCurrent) and reads no
    // shared render state: the handler, the embedded views and the SwiftUI layout are the claim's. Runs outside the
    // lock — it calls back into the host and into the UX helper's layout load.
    private func showNow(layoutPage: LayoutPageExecutePayload,
                         startDate: Date,
                         selectionId: String,
                         claim: RenderClaim) {
        pendingPayload = nil
        claim.handler?(RoktEvent.HideLoadingIndicator())
        let uxHelper = RoktUX()
        initialStateBag(uxHelper: uxHelper, selectionId: selectionId, onRoktEvent: claim.handler)

        if let defaultLayoutLoader = claim.defaultLayoutLoader {
            uxHelper.loadLayout(
                startDate: startDate,
                pageModel: layoutPage.pageModel,
                layoutPluginViewStates: layoutPage.cacheProperties?.pluginViewStates,
                defaultLayoutLoader: defaultLayoutLoader,
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
                layoutLoaders: claim.layoutLoaders,
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
    }

    // Determines and schedules the appropriate time to show the widget
    private func show(_ payload: ExecutePayload) {
        showNow(payload: payload)
    }

    // The event handler is not set here: it is stamped with the placement's other shared render state in admitPlacement,
    // under the generation lock.
    private func setSharedItems(attributes: [String: String],
                                config: RoktConfig?) {
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

    // `onRoktEvent` is the handler claimed for the placement's render, not the shared `roktEvent`, which a later
    // placement may own by now.
    private func initialStateBag(uxHelper: AnyObject? = nil,
                                 selectionId: String? = nil,
                                 onRoktEvent: ((RoktEvent) -> Void)?) {
        let executeId = selectionId ?? UUID().uuidString
        stateManager.addState(
            id: executeId,
            state: ExecuteStateBag(
                uxHelper: uxHelper,
                onRoktEvent: onRoktEvent
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
            // Only while this placement still owns the shared callbacks: a later placement may be loading on them.
            clearCallBacks(ownedBy: executeId)
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
            // This placement's embedded views and SwiftUI layout left the shared slots when its render was claimed, so
            // there is nothing of its own to clear here; callOnUnLoad releases the shared callbacks only while they are
            // still this placement's.
            callOnUnLoad(executeId)
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

    /// Ends a placement with a failure: its result was discarded because `clearSession` landed after it started, its
    /// experience decoded to nothing renderable, or its offers request failed. The failure is reported through the
    /// handler that placement started with, never the shared `roktEvent`: `isExecuting` is released before the result
    /// is checked, so a placement started on another queue inside that window — in the same session or after a
    /// `clearSession` — may already own `roktEvent` and `placements`, and it must neither receive this failure nor
    /// lose its state. Shared state is compared and cleared in one hold of the generation lock (clearCallBacks(ownedBy:)),
    /// so a placement admitted on another queue in that window is never cleared by this one. The two callbacks to the
    /// host run before it, outside the lock.
    private func concludeFailed(selectionId: String, onRoktEvent: (RoktEvent) -> Void) {
        unitTest_duringPlacementFailure?()
        onRoktEvent(RoktEvent.HideLoadingIndicator())
        onRoktEvent(RoktEvent.PlacementFailure(identifier: nil))
        clearCallBacks(ownedBy: selectionId)
    }

    /// Releases the shared event handler, embedded views and SwiftUI layout, but only while `selectionId` still owns
    /// them, comparing and clearing in one hold of the generation lock: a placement admitted on another queue
    /// (admitPlacement stamps its id under the same lock) is never cleared by an earlier placement's failure or by its
    /// last layout closing. Nothing under the hold waits or calls out.
    private func clearCallBacks(ownedBy selectionId: String) {
        sessionGenerationLock.lock()
        defer { sessionGenerationLock.unlock() }
        guard executingSelectionId == selectionId else { return }
        unitTest_duringCallbackClear?()
        placements = nil
        _swiftUiExecuteLayout = nil
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
    // A batch names the session that produced it, and the origin is passed straight through: no
    // decision is made here. The service decides per batch, from one read of the session manager,
    // whether that session is still the stored one with an unexpired token (sent with its bearer,
    // unstamped) or not (stamped with its session id, no Authorization). Without an origin the
    // batch follows the live session.
    func dispatchTxnEvents(_ events: [TxnEvent], originSessionId: String? = nil) {
        guard !events.isEmpty, let roktTagId else { return }
        let service = makeTxnEventServiceOverride?(roktTagId) ?? defaultTxnEventService(roktTagId: roktTagId)
        Task {
            if let originSessionId, !originSessionId.isEmpty {
                try? await service.send(events: events, originSessionId: originSessionId)
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
        // against a new generation, or the new epoch against an old one; and it hands its request — built before
        // this lock is taken — to the network stack under this lock (handOffIfCurrent: the task's creation and
        // resume), so no request leaves for a session this call has ended.
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

    /// Admits a placement in one hold of the generation lock. It reads the state the placement starts from — the
    /// generation its results are checked against, and whether it must bypass the cache — and stamps the placement as
    /// the owner of the shared render state: its selection id, its embedded views, its SwiftUI layout and its event
    /// handler. Read as two separate values, a clearSession on another queue could land between the generation and the
    /// bypass and hand the placement the new generation with the bypass still off — and the cache read is a direct file
    /// read, so the departing customer's experience would be served and every later generation check would accept it
    /// as current. Stamped outside the hold, an earlier placement's failure concluding on another queue
    /// (clearCallBacks(ownedBy:)) could compare against the previous owner and then clear this placement's state.
    /// Nothing under the hold waits or calls out; the ShowLoadingIndicator callback to the host follows it.
    private func admitPlacement(
        selectionId: String,
        placements: [String: RoktEmbeddedView]?,
        swiftUiLayout: LayoutLoader?,
        onRoktEvent: ((RoktEvent) -> Void)?
    ) -> (generation: Int, bypassCache: Bool) {
        sessionGenerationLock.lock()
        defer { sessionGenerationLock.unlock() }
        let generation = sessionGeneration
        unitTest_duringPlacementStart?()
        executingSelectionId = selectionId
        self.placements = placements
        _swiftUiExecuteLayout = swiftUiLayout
        roktEvent = onRoktEvent
        return (generation, mustBypassCacheOnNextExecute)
    }

    /// Runs `commit` under the generation lock while `generation` is still current and returns true; returns
    /// false, running nothing, once clearSession has moved the generation. A clearSession arriving on another
    /// queue waits for a commit in progress, so a response is committed whole or not at all — never half of it.
    /// The commit is the short half of handling a response: everything proportional to the response's size — its
    /// parse, the decode of its echoed events on the helper thread, the direct reads of the cached view-state files —
    /// has already run outside this lock (prepareLayoutPageExecutePayload), and a commit that is refused drops all of
    /// it, writing and queuing nothing. Under the lock the commit writes the session-owned state in memory (the legacy
    /// session id, the sent-event hashes, the timings) and QUEUES its writes — the real-time event store's add, any
    /// new plugin view-state file and the experience cache's eviction-and-write — on those stores' own serial queues,
    /// where they run after the lock is released. It reads and writes no file itself and never waits on another
    /// thread, on the network or on another queue's file work, so a clearSession's wait is bounded by a handful of
    /// memory writes and enqueues. Keep it that way: anything that grows with the response belongs in the prepare, and
    /// a longer hold here is a longer stall for the host's clearSession call, often on the main thread. The same guard
    /// also holds two other short steps of a placement: the build of its offers service before the request is sent (an
    /// in-memory construction and the session store's epoch read, in execute) and the hand-off of that request to the
    /// network stack (handOffIfCurrent: the creation and resume of the task for a request already built); neither waits
    /// on anything either.
    func commitIfCurrent(generation: Int, _ commit: () -> Void) -> Bool {
        sessionGenerationLock.lock()
        defer { sessionGenerationLock.unlock() }
        guard sessionGeneration == generation else { return false }
        commit()
        return true
    }

    /// Runs `handOff` under the generation lock while `generation` is still current and returns true; returns false,
    /// running nothing, once clearSession has moved the generation. The hand-off is the one call that gives a
    /// placement's offers request to the network stack. The URLRequest — its URL, its headers and the JSON encoding of
    /// its body, which grows with the partner's attributes — is built by OffersClient before this lock is taken; what
    /// runs here creates the URLSession task from it and resumes it, a synchronous enqueue that returns as soon as the
    /// request is queued and never waits on its response. Held there, the lock makes the decision to send and the send
    /// itself one step: a clearSession on another queue lands wholly before it, and nothing is sent for the departing
    /// customer, or wholly after it, when the request is already queued and cannot be recalled. Its response is then
    /// fenced out: commitIfCurrent refuses the render and the cache write, the store's epoch refuses the session it
    /// carries (TxnSessionManager.update), and captureUntriggeredEvents drops its echoed events, so nothing from it is
    /// shown or persisted. The hold is bounded by that task creation and resume — never by the request's encoding,
    /// never by the network; keep it that way.
    func handOffIfCurrent(generation: Int, _ handOff: () -> Void) -> Bool {
        commitIfCurrent(generation: generation, handOff)
    }

    /// Decides, in one hold of the generation lock, whether a placement's experience may be handed to the renderer, and
    /// takes the inputs the render needs out of the shared slots: the event handler, the embedded views and the SwiftUI
    /// layout the placement was admitted with. Returns nil, taking nothing, once clearSession has moved the generation
    /// or a later placement owns the shared state (a second selectPlacements admitted after this one released
    /// `isExecuting`). The embedded views and SwiftUI layout are consumed here, so a later placement's are never
    /// rendered into, or cleared, by this one's render; the handler stays in its slot for the ownership-checked release
    /// when the placement's last layout closes. Nothing under this hold waits or calls out: the render itself — the
    /// HideLoadingIndicator callback to the host and the UX helper's layout load, which attaches views and may
    /// synchronise with the main thread — runs after it, outside the lock, on the claimed inputs. Held through the
    /// render instead, the lock could be waited for by the main thread inside clearSession while the render, on the
    /// host's calling queue on the cached path, waited for the main thread. A clearSession that lands after the claim
    /// finds a placement that is already the renderer's: it stays on screen and its events are attributed to the
    /// session it started in.
    private func claimRenderIfCurrent(generation: Int, selectionId: String) -> RenderClaim? {
        sessionGenerationLock.lock()
        defer { sessionGenerationLock.unlock() }
        guard sessionGeneration == generation, executingSelectionId == selectionId else { return nil }
        unitTest_duringRenderClaim?()
        let claim = RenderClaim(handler: roktEvent, layoutLoaders: placements, defaultLayoutLoader: swiftUiExecuteLayout)
        placements = nil
        _swiftUiExecuteLayout = nil
        return claim
    }

    // The offers response echoes events for the next placement to forward. Captured after a
    // clearSession, they would re-seed the store that call just emptied.
    func captureUntriggeredEvents(_ events: [UntriggeredRealTimeEvent], generation: Int) {
        // Checked and QUEUED under the generation lock, as one step: the store's add is queued on its own serial
        // queue and runs there, so the hold is bounded by the enqueue and the file write never runs on this thread —
        // the offers request's own task — nor under this lock. clearSession queues the store's clear under the same
        // lock, so on the store's queue an accepted capture's write lands before a later clear and never after it,
        // and a capture that finds the generation moved queues nothing. Nothing on the store's queue takes this lock.
        sessionGenerationLock.lock()
        defer { sessionGenerationLock.unlock() }
        guard sessionGeneration == generation else { return }
        unitTest_duringEventCapture?()
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
    ///   - swiftUiLayout: The SwiftUI layout to render into, for the SwiftUI integration
    ///   - config: An object which defines RoktConfig
    ///   - placementOptions: Optional placement options containing timing data from joint SDKs
    ///   Placement and second item is widget height
    func execute(
        viewName: String? = nil,
        attributes: [String: String],
        placements: [String: RoktEmbeddedView]? = nil,
        swiftUiLayout: LayoutLoader? = nil,
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
        // The placement is admitted in one hold of the generation lock (admitPlacement): the generation and the cache
        // bypass are read together, so a clearSession on another queue lands wholly before or wholly after this
        // placement's start, and the placement is stamped as the owner of the shared render state in the same hold, so
        // a failure concluding on another queue can never compare against the previous owner and then clear this one.
        // The bypass is latched once per execute: both cache reads in it — the experience response and the view state
        // read later in prepareLayoutPageExecutePayload — see one answer, read once below (readsFromCache). Disarmed only
        // when an execute fetches a fresh experience, so a failed placement keeps the next one off the cache.
        let start = admitPlacement(
            selectionId: selectionId, placements: placements, swiftUiLayout: swiftUiLayout, onRoktEvent: composedEventHandler
        )
        let generation = start.generation
        cacheSuppressedForCurrentExecute = start.bypassCache
        // The session the placement started in — a failure discarded after clearSession is reported against it.
        let departingSessionId = sessionManager.getCurrentSessionIdWithoutExpiring()
        let startDate = Date()
        if let tagId = roktTagId {
            composedEventHandler(RoktEvent.ShowLoadingIndicator())
            setSharedItems(attributes: attributes, config: config)

            if #available(iOS 15, *) {
                FontManager.reRegisterFonts {
                    // use the available cached experience
                    let cacheAttributes = self.roktConfig.cacheConfig.getCacheAttributesOrFallback(attributes)
                    // Whether this execute reads the cache — the experience response here and, in the prepare, the view
                    // state that goes with it — is decided once, from the bypass admitted with the generation, so both
                    // reads see the same answer whatever another placement does meanwhile.
                    let readsFromCache = self.shouldReadFromCache()

                    if readsFromCache,
                       let cachedExperience = ExperienceCacheManager.getCachedExperienceResponse(
                           viewName: viewName,
                           attributes: cacheAttributes,
                           cacheDuration: self.roktConfig.cacheConfig.cacheDuration
                       ) {
                        self.unitTest_beforeCacheHitCommit?()
                        onExperiencesRequestEnd()
                        self.isExecuting = false

                        // A cached experience is prepared outside the generation lock — parsed, its echoed events decoded,
                        // its cached view state read — on the thread the host called from, and then committed under the
                        // lock (legacy session id, echoed events, view state) behind the same fence as a network response,
                        // and re-checked before the render: a clearSession since the placement started discards it whole,
                        // and a clearSession on another thread — the host's main thread, for a placement started from a
                        // background queue — never waits for the parse.
                        let prepared = self.prepareLayoutPageExecutePayload(
                            cachedExperience, viewName: viewName, attributes: attributes, readsFromCache: readsFromCache
                        )
                        var layoutPageExecutePayload: LayoutPageExecutePayload?
                        let committed = self.commitIfCurrent(generation: generation) {
                            guard let prepared else { return }
                            layoutPageExecutePayload = self.commitLayoutPageExecutePayload(prepared, selectionId: selectionId)
                        }
                        guard committed else {
                            RoktLogger.shared.info("Discarding a cached placement that resolved after clearSession")
                            self.concludeFailed(selectionId: selectionId, onRoktEvent: composedEventHandler)
                            return
                        }
                        self.unitTest_afterCommitBeforePayloadCheck?()
                        guard let layoutPageExecutePayload else {
                            RoktLogger.shared.info("Failing a cached placement whose experience has nothing to render")
                            self.concludeFailed(selectionId: selectionId, onRoktEvent: composedEventHandler)
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
                        // The check that the session is still current and that this placement still owns the shared
                        // handler and views, and the claim of those inputs for the render, are one step under the
                        // generation lock (claimRenderIfCurrent): a clearSession lands wholly before it, and the cached
                        // placement is discarded, or wholly after it, when the placement is already the renderer's.
                        guard let claim = self.claimRenderIfCurrent(generation: generation, selectionId: selectionId) else {
                            RoktLogger.shared.info(
                                "Discarding a cached placement that resolved after clearSession or a later placement took over"
                            )
                            self.concludeFailed(selectionId: selectionId, onRoktEvent: composedEventHandler)
                            return
                        }

                        let payload = ExecutePayload(layoutPage: layoutPageExecutePayload,
                                                     startDate: startDate,
                                                     selectionId: selectionId,
                                                     claim: claim)
                        self.show(payload)
                    } else {
                        let onSuccess: (String?) -> Void = { page in
                            onExperiencesRequestEnd()
                            // Released before the fence so a discarded completion cannot wedge execute.
                            self.isExecuting = false

                            // The response is prepared outside the generation lock — parsed, its echoed events decoded,
                            // its cached view state read; everything proportional to its size — on this thread (the
                            // offers completion queue, the main queue by default), and then committed under the lock,
                            // only while the placement's generation is current: the cache write, the legacy session id,
                            // the echoed events, the view state. A clearSession on another queue never waits for the
                            // prepare, and either waits for the short commit or fences it out, never half of it; a
                            // commit fenced out drops everything prepared, writing and queuing nothing.
                            // Use cacheAttributes for plugin view states if cache is enabled for consistency
                            let attributesForPluginStates = self.roktConfig.cacheConfig
                                .getCacheAttributesOrFallback(attributes)
                            let prepared = page.flatMap {
                                self.prepareLayoutPageExecutePayload(
                                    $0, viewName: viewName, attributes: attributesForPluginStates, readsFromCache: readsFromCache
                                )
                            }
                            var layoutPageExecutePayload: LayoutPageExecutePayload?
                            let committed = self.commitIfCurrent(generation: generation) {
                                guard let page else { return }
                                self.mustBypassCacheOnNextExecute = false
                                // Cache the experience if applicable. The call queues one barrier on the cache's own
                                // queue — the directory scan that evicts the superseded responses, their deletes and
                                // the write all run there — and returns as soon as it is queued: no file access on
                                // this thread (the offers completion queue, the main queue by default) and none
                                // under the lock. Queued under the lock, the write is ordered before the clear a
                                // later clearSession queues under the same lock, so that clear removes it.
                                if self.isCacheEnabledAndConfigured() {
                                    let cacheAttributes = self.roktConfig.cacheConfig.getCacheAttributesOrFallback(attributes)
                                    ExperienceCacheManager.cacheExperienceResponse(
                                        viewName: viewName,
                                        attributes: cacheAttributes,
                                        experienceResponse: page,
                                        success: {
                                            // Runs on the cache's queue once the write has landed. A clearSession
                                            // since this commit has already queued its clear behind that write; this
                                            // re-check is a second line behind that ordering, and clearing an empty
                                            // cache again is harmless. The whole cache goes, not one entry: every
                                            // write is already preceded by a full eviction (the cache holds one
                                            // experience), the next session's own write would share this key, and a
                                            // fresh experience cleared this way costs the new session one refetch —
                                            // never a wrong experience.
                                            if self.currentSessionGeneration() != generation {
                                                ExperienceCacheManager.clearCache()
                                            }
                                        }
                                    )
                                }

                                guard let prepared else { return }
                                layoutPageExecutePayload = self.commitLayoutPageExecutePayload(prepared, selectionId: selectionId)
                            }
                            guard committed else {
                                RoktLogger.shared.info("Discarding a placement that completed after clearSession")
                                self.concludeFailed(selectionId: selectionId, onRoktEvent: composedEventHandler)
                                return
                            }
                            self.unitTest_afterCommitBeforePayloadCheck?()
                            guard let layoutPageExecutePayload else {
                                RoktLogger.shared.info("Failing a placement whose response has nothing to render")
                                self.concludeFailed(selectionId: selectionId, onRoktEvent: composedEventHandler)
                                return
                            }
                            // The check that the session is still current and that this placement still owns the shared
                            // handler and views, and the claim of those inputs for the render, are one step under the
                            // generation lock (claimRenderIfCurrent): a clearSession lands wholly before it, and the
                            // placement is discarded (the commit's state went with the clear, under the lock), or wholly
                            // after it, when the placement is already the renderer's — it stays on screen and its events
                            // are attributed to the session it started in.
                            guard let claim = self.claimRenderIfCurrent(generation: generation, selectionId: selectionId) else {
                                RoktLogger.shared.info(
                                    "Discarding a placement that completed after clearSession or a later placement took over"
                                )
                                self.concludeFailed(selectionId: selectionId, onRoktEvent: composedEventHandler)
                                return
                            }

                            let payload = ExecutePayload(
                                layoutPage: layoutPageExecutePayload,
                                startDate: startDate,
                                selectionId: selectionId,
                                claim: claim
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
                                self.concludeFailed(selectionId: selectionId, onRoktEvent: composedEventHandler)
                                return
                            }
                            self.executeFailureHandler(error, statusCode, response)
                            self.concludeFailed(selectionId: selectionId, onRoktEvent: composedEventHandler)
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
                            self.concludeFailed(selectionId: selectionId, onRoktEvent: composedEventHandler)
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
            clearCallBacks(ownedBy: selectionId)
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

    /// The first half of handling an experience response, run OUTSIDE the generation lock on the caller's thread: the
    /// parse of the experience, the decode of the events it echoes for the next placement (on the helper thread, see
    /// decodeOnSeparateThread) and, when `readsFromCache`, the direct file reads of the cached view state that goes with
    /// it — the view's sent-event hashes and each plugin's existing view state. All of it grows with the response and
    /// none of it touches session-owned state or writes anything, so a clearSession on another thread never waits for
    /// it. Returns nil when the page is not UTF-8 or the experience does not parse; the placement is then failed by its
    /// caller. What is returned goes to commitLayoutPageExecutePayload under the lock, which runs only if the generation
    /// is still current: a clearSession that lands in between refuses the commit and everything prepared here is dropped.
    /// `readsFromCache` is the answer read once per execute from the bypass admitted with the generation, never re-read
    /// here, so the view state is read under the same decision as the experience response.
    func prepareLayoutPageExecutePayload(_ page: String,
                                         viewName: String? = nil,
                                         attributes: [String: String],
                                         readsFromCache: Bool) -> PreparedLayoutPage? {
        guard let pageData = page.data(using: .utf8) else {
            return nil
        }

        // Single parse: the UX helper decodes the experience response once and reports
        // the parse window; the resulting page model is reused for rendering.
        guard let parseResult = RoktUX.parseExperience(page) else {
            return nil
        }

        var echoedEvents: [UntriggeredRealTimeEvent]?
        var cachedViewState: PreparedCachedViewState?
        if let pageModel = parseResult.pageModel {
            // The second decode of the response, for the events it echoes; nil when they do not decode.
            echoedEvents = (try? decodeOnSeparateThread(UntriggeredEventsContainer.self, pageData))?.untriggeredEvents
            if readsFromCache {
                cachedViewState = readCachedViewState(for: pageModel, viewName: viewName, attributes: attributes)
            }
        }
        unitTest_duringPayloadPrepare?()

        return PreparedLayoutPage(
            sessionId: parseResult.sessionId,
            parseStart: parseResult.parseStart,
            parseEnd: parseResult.parseEnd,
            pageModel: parseResult.pageModel,
            echoedEvents: echoedEvents,
            cachedViewState: cachedViewState
        )
    }

    /// Reads the cached view state an experience is rendered with, outside the generation lock: the sent-event hashes
    /// for the view, and for each plugin of the experience the view state on disk — nil where there is none yet. Direct
    /// synchronous file reads; nothing is created or written here. A plugin whose state is missing gets one in the
    /// commit, so a placement whose commit is refused leaves no file behind for the next session.
    private func readCachedViewState(for pageModel: RoktUXPageModel,
                                     viewName: String?,
                                     attributes: [String: String]) -> PreparedCachedViewState {
        // For cached experiences, use cacheAttributes for consistency
        let cacheAttributes = roktConfig.cacheConfig.getCacheAttributesOrFallback(attributes)
        let experiencesViewState = ExperienceCacheManager.getCachedExperiencesViewState(
            viewName: viewName, attributes: cacheAttributes
        )
        let pluginViewStates = pageModel.layoutPlugins?.map { plugin in
            PreparedPluginViewState(
                pluginId: plugin.pluginId,
                cached: ExperienceCacheManager.getCachedPluginViewState(
                    pluginId: plugin.pluginId, viewName: viewName, attributes: cacheAttributes
                )
            )
        }
        return PreparedCachedViewState(
            viewName: viewName,
            cacheAttributes: cacheAttributes,
            sentEventHashes: Array(experiencesViewState?.sentEventHashes ?? .init()),
            pluginViewStates: pluginViewStates
        )
    }

    /// The second half of handling an experience response, run UNDER the generation lock — always inside
    /// commitIfCurrent, so only while the placement's generation is still current. Writes the session-owned state in
    /// memory and queues the file writes; every step is a memory write or an enqueue, none parses, decodes, reads a file
    /// or waits, so the hold is short whatever the response's size. In order: the legacy session id (a UserDefaults
    /// write, persisted by the system off this thread, which, when the id changes, queues the real-time event store's
    /// clear), the parse timings; then, when the experience has a page, the echoed events' add queued on the store's
    /// serial queue behind that clear, the page timings, and the view state the render is handed — the sent-event
    /// hashes, and for each plugin the state read in the prepare or, where there was none, a new one whose file write is
    /// queued on the cache's own queue. Queued under the lock, each write is ordered before the clears a later
    /// clearSession queues under the same lock, so that clear removes them. Returns nil when the experience decoded to
    /// no page; the session id is still committed, as the server rolled it forward.
    func commitLayoutPageExecutePayload(_ prepared: PreparedLayoutPage, selectionId: String) -> LayoutPageExecutePayload? {
        sessionManager.updateSessionId(newSessionId: prepared.sessionId)

        processedTimingsRequests?.setExperienceJsonParseTimes(
            selectionId: selectionId,
            start: prepared.parseStart,
            end: prepared.parseEnd
        )

        guard let pageModel = prepared.pageModel else {
            return nil
        }
        if let echoedEvents = prepared.echoedEvents {
            RealTimeEventManager.shared.addUntriggeredEvents(echoedEvents)
        }

        processedTimingsRequests?.setPageProperties(
            selectionId: selectionId,
            sessionId: prepared.sessionId,
            pageId: pageModel.pageId,
            pageInstanceGuid: pageModel.pageInstanceGuid
        )

        guard let cachedViewState = prepared.cachedViewState else {
            // No cache: scope event de-duplication to this execute. The cache branch below
            // seeds `sentEventHashes` per view; without a reset here the set is only ever
            // (re)initialised on the cache path, so for non-cached executes it accumulates
            // hashes for the whole process lifetime — growing unbounded and, when an event
            // hash repeats across executes (e.g. a reused session id), silently dropping
            // events that were already "sent" by an earlier, unrelated execute.
            sentEventHashes = ThreadSafeSet()
            return LayoutPageExecutePayload(pageModel: pageModel,
                                            cacheProperties: nil)
        }

        sentEventHashes = ThreadSafeSet(cachedViewState.sentEventHashes)
        let viewName = cachedViewState.viewName
        let cacheAttributes = cachedViewState.cacheAttributes
        // A plugin with no view state on disk gets its initial one here: built in memory, its file write queued on the
        // cache's queue under this lock, so it lands before — and is removed by — the clear a later clearSession queues.
        let pluginViewStates = cachedViewState.pluginViewStates?.map { pluginViewState in
            pluginViewState.cached ?? ExperienceCacheManager.createPluginViewStateCache(
                pluginId: pluginViewState.pluginId, viewName: viewName, attributes: cacheAttributes
            )
        }

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
        // The layout is stamped with the placement's other shared render state in admitPlacement, under the generation
        // lock, so a render claimed for an earlier placement cannot take it.
        execute(
            viewName: viewName,
            attributes: attributes,
            swiftUiLayout: layout,
            config: config,
            placementOptions: placementOptions,
            onRoktEvent: {roktEvent in
                onRoktEvent?(roktEvent)
            }
        )
    }

    /// Releases `isExecuting` and reports a failed offers request. The placement is then failed by its caller through
    /// the handler it started with (see concludeFailed), never through the shared `roktEvent`: once `isExecuting` is
    /// released another placement may own it.
    internal func executeFailureHandler(_ error: Error, _ statusCode: Int?, _ response: String) {
        isExecuting = false
        // Don't report diagnostics for 429 (Too Many Requests) status code
        if let code = statusCode, code != 429 {
            sendDiagnostics(Self.executeDiagnosticCode, error: error, statusCode: statusCode, response: response)
        }
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

        var snapshot = TxnSessionPersistence.readRaw(store: store)
        guard let sessionId = snapshot.sessionId,
              !sessionId.isEmpty,
              let token = snapshot.token,
              !token.isEmpty
        else {
            RoktLogger.shared.warning(
                "Rokt.getSession returned nil: no session is present."
            )
            return nil
        }

        // An absent expiry key is not a verdict on the session: the store writes its keys one at a time,
        // so a read between the token write and the expiry write must return nil without touching it.
        guard let rawExpiry = store.string(forKey: TxnSessionStoreKeys.expiresAt), !rawExpiry.isEmpty else {
            RoktLogger.shared.warning(
                "Rokt.getSession returned nil: no session is present."
            )
            return nil
        }
        // The expiry landed after the snapshot was taken: a write was in progress. Read the session again so
        // the expiry decision below sees the same write the expiry came from, not a half-written session.
        if snapshot.expiresAt == nil {
            snapshot = TxnSessionPersistence.readRaw(store: store)
        }

        // A present but unreadable or out-of-range expiry counts as expired, matching restore.
        if TxnSessionPersistence.clearIfExpired(expiresAt: snapshot.expiresAt, store: store, clock: Date.init) {
            RoktLogger.shared.warning(
                "Rokt.getSession returned nil: session token is expired."
            )
            return nil
        }

        guard let expiresAt = snapshot.expiresAt,
              let expiresAtMs = TxnSessionPersistence.epochMilliseconds(expiresAt)
        else {
            TxnSessionPersistence.clear(store: store)
            RoktLogger.shared.warning(
                "Rokt.getSession returned nil: persisted session expiry is invalid."
            )
            return nil
        }
        return RoktSession(
            sessionId: sessionId,
            sessionToken: token,
            expiresAtMilliseconds: expiresAtMs
        )
    }

    /// Session id for the diagnostics/timings header, or nil when no unexpired session is bound.
    ///
    /// Deliberately not used by ``getSessionId()``: that reports whatever the partner last set,
    /// which carries no expiry to gate on.
    func currentValidSessionId(clock: () -> Date = Date.init) -> String? {
        guard let roktTagId else { return nil }
        return TxnSessionManager.currentValidSessionId(
            roktTagId: roktTagId,
            store: txnSessionStore,
            clock: clock
        )
    }

    /// Uses a future partner-supplied expiry when present; otherwise (or when already past)
    /// falls back to now + ``partnerSessionTokenDefaultTTL``. An expiry further out than
    /// `TxnSessionPersistence.maxTokenTTL` is capped when the session is seeded.
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

    /// Decodes on a thread given a larger stack than a dispatch worker's (8 MB at least): the decoder recurses once per
    /// level of the JSON, and a deeply nested response would otherwise overflow the caller's stack. The caller waits for
    /// that thread here, so this is called from the prepare of a response (prepareLayoutPageExecutePayload), never
    /// under the generation lock: a wait held under the lock would be a wait imposed on every clearSession.
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
    let claim: RenderClaim
}

/// What a placement's render is given once its experience has been claimed for it under the generation lock (see
/// claimRenderIfCurrent): the event handler and the embedded views it was admitted with, and the SwiftUI layout set for
/// it. Taken out of the shared slots in the same hold as the check, so the render reads nothing shared afterwards and a
/// later placement's handler and views are never rendered into, or cleared, by this one's render.
struct RenderClaim {
    let handler: ((RoktEvent) -> Void)?
    let layoutLoaders: [String: RoktEmbeddedView]?
    let defaultLayoutLoader: LayoutLoader?
}

/// An experience response between its prepare and its commit (see prepareLayoutPageExecutePayload): what the parse and
/// the decodes produced and the cached view state read for it, none of it written anywhere yet. Handed to
/// commitLayoutPageExecutePayload under the generation lock, or dropped whole when the commit is refused.
struct PreparedLayoutPage {
    let sessionId: String
    let parseStart: Date
    let parseEnd: Date
    /// Nil when the experience decoded to no page: the commit still records the session id and the placement fails.
    let pageModel: RoktUXPageModel?
    /// The events the response echoes for the next placement; nil when there is no page or they did not decode.
    let echoedEvents: [UntriggeredRealTimeEvent]?
    /// Nil when this execute does not read the cache (cache off, or bypassed after clearSession) or there is no page.
    let cachedViewState: PreparedCachedViewState?
}

/// The cached view state read for an experience outside the generation lock: the sent-event hashes for the view and,
/// for each plugin of the experience, the state on disk — nil where there is none yet, which the commit creates.
struct PreparedCachedViewState {
    let viewName: String?
    let cacheAttributes: [String: String]
    let sentEventHashes: [String]
    let pluginViewStates: [PreparedPluginViewState]?
}

/// One plugin's view state as read in the prepare: nil where no valid state is on disk.
struct PreparedPluginViewState {
    let pluginId: String
    let cached: RoktPluginViewState?
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
