import Foundation
import UIKit
import AppTrackingTransparency
internal import RoktUXHelper

let defaultTimeout: Double = 9000
let defaultFontTimeout: Double = 30 // second
let defaultDelay: Double = 1000

class RoktInternalImplementation {
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
    private var clientTimeoutMilliseconds: Double = defaultTimeout
    private var defaultLaunchDelayMilliseconds: Double = defaultDelay
    private var loadingFonts = false
    private var pendingPayload: ExecutePayload?
    private var isExecuting = false
    private var placements: [String: RoktEmbeddedView]?

    // Caching is disabled by default internally (enableCache: false).
    // If a consumer specifies a CacheConfig via the builder, it will use their setting (defaults to true).
    var roktConfig: RoktConfig = RoktConfig.Builder().cacheConfig(RoktConfig.CacheConfig(enableCache: false)).build()

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
        } else {
            callOnRoktEvent(executeId, event: uxEvent.mapToRoktEvent)
        }
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
                if let eventListener = self.roktEventMap[kDefaultRoktInitEvent] {
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
                self.sendDiagnostics(kAPIInitErrorCode, error: error, statusCode: statusCode, response: response)
            }
            if let eventListener = self.roktEventMap[kDefaultRoktInitEvent] {
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
        placementOptions: PlacementOptions? = nil,
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
            RoktAPIHelper.sendDiagnostics(message: kNotInitializedCode,
                                          callStack: isInitFailedForFont ? kFontFailedError : kInitFailedError,
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
                RoktAPIHelper.sendDiagnostics(message: kTrackErrorCode, callStack: kTrackError, severity: .warning)
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
                    self.executeAfterFontRegistration(
                        viewName: viewName,
                        attributes: attributes,
                        tagId: tagId,
                        selectionId: selectionId,
                        trackingConsent: trackingConsent,
                        startDate: startDate,
                        onExperiencesRequestStart: onExperiencesRequestStart,
                        onExperiencesRequestEnd: onExperiencesRequestEnd
                    )
                }
            }
        } else {
            isExecuting = false
            RoktLogger.shared.error("SDK is not initialized - cannot execute")
            composedEventHandler(RoktEvent.PlacementFailure(identifier: nil))
            clearCallBacks()
            RoktAPIHelper.sendDiagnostics(message: kNotInitializedCode,
                                          callStack: isInitFailedForFont ? kFontFailedError : kInitFailedError,
                                          severity: .info)
        }
    }

    // swiftlint:disable:next function_body_length
    @available(iOS 15, *)
    private func executeAfterFontRegistration(
        viewName: String?,
        attributes: [String: String],
        tagId: String,
        selectionId: String,
        trackingConsent: UInt?,
        startDate: Date,
        onExperiencesRequestStart: @escaping () -> Void,
        onExperiencesRequestEnd: @escaping () -> Void
    ) {
        let cacheAttributes = roktConfig.cacheConfig.getCacheAttributesOrFallback(attributes)

        if isCacheEnabledAndConfigured(),
           let cachedExperience = ExperienceCacheManager.getCachedExperienceResponse(
               viewName: viewName,
               attributes: cacheAttributes,
               cacheDuration: roktConfig.cacheConfig.cacheDuration
           ) {
            onExperiencesRequestEnd()
            isExecuting = false

            guard let layoutPageExecutePayload = processLayoutPageExecutePayload(
                cachedExperience, selectionId: selectionId, viewName: viewName, attributes: attributes
            ) else {
                conclude(withFailure: true)
                return
            }

            RoktAPIHelper.sendDiagnostics(
                message: kCacheHitCode,
                callStack: String(format: kCacheHitMessage, viewName ?? ""),
                severity: .info,
                additionalInfo: [
                    kCacheDurationKey: String(roktConfig.cacheConfig.cacheDuration),
                    kCacheAttributesKey: Array(cacheAttributes.keys).description
                ]
            )

            let payload = ExecutePayload(layoutPage: layoutPageExecutePayload,
                                         startDate: startDate,
                                         selectionId: selectionId)
            show(payload)
        } else {
            fetchAndProcessExperience(
                viewName: viewName,
                attributes: attributes,
                tagId: tagId,
                selectionId: selectionId,
                trackingConsent: trackingConsent,
                startDate: startDate,
                onExperiencesRequestStart: onExperiencesRequestStart,
                onExperiencesRequestEnd: onExperiencesRequestEnd
            )
        }
    }

    @available(iOS 15, *)
    private func fetchAndProcessExperience(
        viewName: String?,
        attributes: [String: String],
        tagId: String,
        selectionId: String,
        trackingConsent: UInt?,
        startDate: Date,
        onExperiencesRequestStart: @escaping () -> Void,
        onExperiencesRequestEnd: @escaping () -> Void
    ) {
        RoktAPIHelper.getExperienceData(
            viewName: viewName,
            attributes: attributes,
            roktTagId: tagId,
            selectionId: selectionId,
            trackingConsent: trackingConsent,
            config: roktConfig,
            onRequestStart: onExperiencesRequestStart,
            successLayout: { page in
                onExperiencesRequestEnd()
                self.isExecuting = false

                guard let page else {
                    self.conclude(withFailure: true)
                    return
                }

                if self.isCacheEnabledAndConfigured() {
                    let cacheAttributes = self.roktConfig.cacheConfig
                        .getCacheAttributesOrFallback(attributes)
                    DispatchQueue.background.async {
                        ExperienceCacheManager.cacheExperienceResponse(
                            viewName: viewName,
                            attributes: cacheAttributes,
                            experienceResponse: page
                        )
                    }
                }

                let attributesForPluginStates = self.roktConfig.cacheConfig
                    .getCacheAttributesOrFallback(attributes)
                guard let layoutPageExecutePayload = self.processLayoutPageExecutePayload(
                    page, selectionId: selectionId,
                    viewName: viewName, attributes: attributesForPluginStates
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
        )
    }

    private func isCacheEnabledAndConfigured() -> Bool {
        return initFeatureFlags.isEnabled(.cacheEnabled) && roktConfig.cacheConfig.isCacheEnabled()
    }

    func processLayoutPageExecutePayload(_ page: String,
                                         selectionId: String,
                                         viewName: String? = nil,
                                         attributes: [String: String]) -> LayoutPageExecutePayload? {
        guard let pageData = try? page.data(using: .utf8),
              let pageDecodedData = try? JSONDecoder().decode(RoktUXExperienceResponse.self, from: pageData)
        else {
            return nil
        }
        sessionManager.updateSessionId(newSessionId: pageDecodedData.sessionId)

        guard let pageModel = pageDecodedData.getPageModel() else {
            return nil
        }
        let events = try? JSONDecoder().decode(UntriggeredEventsContainer.self, from: pageData)
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
        placementOptions: PlacementOptions? = nil,
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
            sendDiagnostics(kAPIExecuteErrorCode, error: error, statusCode: statusCode, response: response)
        }
        conclude(withFailure: true)
    }

    func mapEvents(
        viewName: String = "",
        isGlobal: Bool = false,
        onEvent: ((RoktEvent) -> Void)?
    ) {
        if isGlobal, viewName.isEmpty {
            roktEventMap[kDefaultRoktInitEvent] = onEvent
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
            forName: NSNotification.Name(kDownloadingFonts),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadingFonts = true
        }

        // Observer for finished loading fonts
        let finishedObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name(kFinishedDownloadingFonts),
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
