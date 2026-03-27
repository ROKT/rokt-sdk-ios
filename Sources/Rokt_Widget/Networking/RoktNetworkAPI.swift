import Foundation

// MARK: - URL constants (internal — also used by test mocks)

var initResourceUrl: String { "\(baseURL)/v1/init" }
var experiencesResourceURL: String { "\(baseURL)/v1/experiences" }
var eventResourceUrl: String { "\(baseURL)/v2/events" }
var diagnosticsResourceUrl: String { "\(baseURL)/v1/diagnostics" }
var timingsResourceUrl: String { "\(baseURL)/v1/timings" }

// MARK: - API failure messages

private let eventAPIFailureMsg = "response: %@ ,statusCode: %@ ,error: %@"
private let timingsAPIFailureMsg = "response: %@, statusCode: %@, error: %@"

// MARK: - Header keys

private let headerSessionIdKey = "rokt-session-id"
private let headerTrackingConsent = "rokt-apple-tracking-consent"
private let headerIntegrationTypeKey = "rokt-integration-type"
let headerPageInstanceGuidKey = "rokt-page-instance-guid"
let headerPageIdKey = "rokt-page-id"

// MARK: - Init response keys

private let clientTimeoutKey = "clientTimeoutMilliseconds"
private let defaultLaunchDelayKey = "defaultLaunchDelayMilliseconds"
private let clientSessionTimeoutKey = "clientSessionTimeoutMilliseconds"
private let logFontKey = "shouldLogFontHappyPath"
private let useFontRegistryUrlKey = "shouldUseFontRegisterWithUrl"
private let roktFlagKey = "roktTrackingStatus"
private let featureFlagKey = "featureFlags"
private let fontsKey = "fonts"

// MARK: - Other single-use constants

private let headerTagIdKey = "rokt-tag-id"
private let headerSdkFrameworkType = "rokt-sdk-framework-type"
private let eventDiagnosticCode = "[EVENT]"
private let fontErrorMessage = "Error downloading font: "
private let timingsDiagnosticCode = "[TIMINGS]"
private let timingsSdkType = "msdk"
private let layoutsSchemaVersionHeader = "rokt-layout-schema-version"
private let layoutsSchemaVersion = "2.3"

// MARK: - Full font log codes

private let fullFontLogCode3 = "[FFL003]"
private let fullFontLogCode4 = "[FFL004]"

internal class RoktNetWorkAPI {
    private static let headerPageIdentifierKey = "rokt-page-identifier"
    /// Rokt initialize API call
    ///
    /// - Parameters:
    ///   - roktTagId: The tag id provided by Rokt, associated with the client's account
    ///   - success: Function to execute after a successfull call to the API. Returns timeout, delay and fonts
    ///   - failure: Function to execute after an unseccessfull call to the API
    class func initialize(roktTagId: String,
                          success: ((InitRespose) -> Void)? = nil,
                          failure: ((Error, Int?, String) -> Void)? = nil) {
        NetworkingHelper.performGet(url: initResourceUrl,
                                    params: nil,
                                    headers: [
                                        headerTagIdKey: roktTagId,
                                        headerSdkFrameworkType: Rokt.shared.roktImplementation.frameworkType.toString
                                    ],
                                    extraErrorCheck: true,
                                    success: { (dict, _, _) in
                                        if let initData = dict as? [String: Any] {
                                            initializeData(initData, success: success)
                                        }
                                    }, failure: failure)
    }

    private class func initializeData(_ initData: [String: Any],
                                      success: ((InitRespose) -> Void)? = nil) {
        if let clientTimeout = initData[clientTimeoutKey] as? Double,
           let defaultLaunchDelay = initData[defaultLaunchDelayKey] as? Double,
           let successCallback = success {
            let roktTrackingStatus = initData[roktFlagKey] as? Bool ?? true
            var fonts = [FontModel]()

            if let fontDicts = initData[fontsKey] as? [[String: String]] {
                fonts = fontDicts.compactMap({ (fontDict) -> FontModel? in
                    FontModel(fontDict: fontDict)
                })
            }

            let clientSessionTimeout =
                initData[clientSessionTimeoutKey] as? Double
            let shouldLogFontHappyPath =
                initData[logFontKey] as? Bool ?? false
            let shouldUseFontRegisterWithUrl =
                initData[useFontRegistryUrlKey] as? Bool ?? false
            var featureFlags = [String: FeatureFlagItem]()
            do {
                if let featureFlagItemsData =
                    initData[featureFlagKey],
                   let featureFlagData =
                    try? JSONSerialization.data(withJSONObject: featureFlagItemsData) {
                    featureFlags = try JSONDecoder().decode(
                        [String: FeatureFlagItem].self,
                        from: featureFlagData)
                }
            } catch {
                featureFlags = [:]
            }

            let initResponseFeatureFlags = InitFeatureFlags(
                roktTrackingStatus: roktTrackingStatus,
                shouldLogFontHappyPath: shouldLogFontHappyPath,
                shouldUseFontRegisterWithUrl: shouldUseFontRegisterWithUrl,
                featureFlags: featureFlags)
            successCallback(InitRespose(timeout: clientTimeout,
                                        delay: defaultLaunchDelay,
                                        clientSessionTimeout: clientSessionTimeout,
                                        fonts: fonts,
                                        featureFlags: initResponseFeatureFlags))
        }
    }

    /// Rokt download fonts API call
    ///
    /// - Parameters:
    ///   - font: The font file that should be downloaded and installed to be used in the widget
    ///   - destination: URL to the file's intended location on the device
    ///   - isLastFont: if `true`, sends a local Notification that all fonts have been downloaded
    ///   - onDownloadComplete: Callback to trigger when the download is complete
    ///   - retryCount: number of times that the download request has been attempted
    class func downloadFont(
        font: FontModel,
        destinationURL: URL,
        isLastFont: Bool,
        onDownloadComplete: @escaping ((_ isLastFont: Bool) -> Void),
        retryCount: Int = 0
    ) {
        NetworkingHelper.shared.downloadFile(
            source: font.url,
            destinationURL: destinationURL,
            requestTimeout: TimeInterval(exactly: defaultFontTimeout)!) { downloadResponse in
            if downloadResponse.downloadError == nil,
               let downloadedFileLocalURL = downloadResponse.downloadedFileLocalURL {
                FontManager.sendFullFontLogs(
                    "Font downloaded to \(downloadedFileLocalURL)",
                    fontLogId: fullFontLogCode3)

                FontManager.registerFont(font: font, fileUrl: downloadedFileLocalURL, isDownloaded: true)
                onDownloadComplete(isLastFont)
            } else if let downloadError = downloadResponse.downloadError {
                if retryCount < maxRetries && NetworkingHelper.retriableResponse(
                    error: downloadError,
                    code: downloadResponse.httpURLResponse?.statusCode) {

                    // Log FFL4
                    FontManager.sendFullFontLogs(
                        "Retry for font file \(destinationURL) error on download \(downloadError)",
                        fontLogId: fullFontLogCode4)

                    downloadFont(
                        font: font,
                        destinationURL: destinationURL,
                        isLastFont: isLastFont,
                        onDownloadComplete: onDownloadComplete,
                        retryCount: retryCount + 1)

                    return
                } else {
                    Rokt.shared.roktImplementation.isInitialized = false
                    Rokt.shared.roktImplementation.isInitFailedForFont = true
                    let callstack = "\(fontErrorMessage) \(font.url), " +
                        "error: \(String(describing: downloadResponse.downloadError.debugDescription))"

                    RoktAPIHelper.sendDiagnostics(message: fontDiagnosticCode, callStack: callstack)
                    RoktLogger.shared.verbose(callstack)
                    onDownloadComplete(isLastFont)
                }
            }

            if isLastFont {
                NotificationCenter.default.post(Notification(name: Notification.Name(finishedDownloadingFonts)))
            }
        }
    }

    /// Rokt event API call
    ///
    /// - Parameters:
    ///   - params: A string dictionary containing the parameters that should be displayed in the widget
    ///   - success: Function to execute after a successfull call to the API
    ///   - failure: Function to execute after an unseccessfull call to the API
    class func sendEvent(paramsArray: [[String: Any]],
                         sessionId: String?,
                         success: (() -> Void)? = nil,
                         failure: ((Error, Int?, String) -> Void)? = nil) {

        guard let tagId = Rokt.shared.roktImplementation.roktTagId else { return }
        NetworkingHelper.performPost(urlString: eventResourceUrl,
                                     bodyArray: paramsArray,
                                     headers: getDefaultHeaders(tagId: tagId),
                                     success: { (_, _, _) in
                                        success?()
                                     },
                                     failure: { (error, statusCode, response) in
                                        // Don't report diagnostics for 429 (Too Many Requests) status code
                                        if let code = statusCode, code != 429 {
                                            let callStack = String(format: eventAPIFailureMsg,
                                                                   response,
                                                                   String(describing: statusCode),
                                                                   error.localizedDescription)

                                            RoktAPIHelper.sendDiagnostics(
                                                message: eventDiagnosticCode,
                                                callStack: callStack,
                                                sessionId: sessionId)

                                            RoktLogger.shared.verbose(callStack)
                                        }
                                        failure?(error, statusCode, response)
                                     })
    }

    /// Rokt diagnostics API call
    ///
    /// - Parameters:
    ///   - params: A string dictionary containing the parameters that should be displayed in the widget
    ///   - success: Function to execute after a successfull call to the API
    ///   - failure: Function to execute after an unseccessfull call to the API
    class func sendDiagnostics(params: [String: Any],
                               success: (() -> Void)? = nil,
                               failure: ((Error, Int?, String) -> Void)? = nil) {

        guard let tagId = Rokt.shared.roktImplementation.roktTagId else { return }
        NetworkingHelper.performPost(url: diagnosticsResourceUrl,
                                     body: params,
                                     headers: getDefaultHeaders(tagId: tagId),
                                     success: { (_, _, _) in
                                        success?()
                                     }, failure: failure)
    }

    /// Generates the default HTTP headers required for Rokt API requests.
    ///
    /// These headers include the Rokt Tag ID and, if available and required, the current session ID.
    /// It also appends the SDK framework type.
    ///
    /// - Parameters:
    ///   - tagId: The Rokt Tag ID to be included in the headers.
    ///   - requestingLayouts: A Boolean indicating if the call is for layouts, which affects session ID retrieval.
    ///                           This is typically `true` for calls to the experiences or placements APIs,
    ///                           and `false` for other calls like event tracking.
    /// - Returns: A dictionary containing the default HTTP headers.
    private class func getDefaultHeaders(tagId: String, requestingLayouts: Bool = false) -> [String: String] {
        var headers: [String: String] = [headerTagIdKey: tagId]

        if let sessionId = getSessionId(requestingLayouts: requestingLayouts), !sessionId.isEmpty {
            headers[headerSessionIdKey] = sessionId
        }

        headers[headerSdkFrameworkType] = Rokt.shared.roktImplementation.frameworkType.toString

        return headers
    }

    /// Get the current sessionId or nil if no session present.
    /// If requesting a layout then session will be validated and expired if required.
    private class func getSessionId(requestingLayouts: Bool) -> String? {
        if requestingLayouts {
            return Rokt.shared.roktImplementation.sessionManager.getCurrentSessionIdForLayoutRequest()
        } else {
            return Rokt.shared.roktImplementation.sessionManager.getCurrentSessionIdWithoutExpiring()
        }
    }

    private class func getTimingsRequestHeaders(tagId: String, timingsRequest: TimingsRequest,
                                                selectionId: String) -> [String: String] {
        var headers: [String: String] = getDefaultHeaders(tagId: tagId)

        // Enrich default headers with integrationType, pageInstanceGuid, pageId, and selectionId
        headers[headerIntegrationTypeKey] = timingsSdkType
        headers["x-rokt-trace-id"] = selectionId

        if let pageInstanceGuid = timingsRequest.pageInstanceGuid {
            headers[headerPageInstanceGuidKey] = pageInstanceGuid
        }

        if let pageId = timingsRequest.pageId {
            headers[headerPageIdKey] = pageId
        }

        return headers
    }

    /// Fetch the Rokt `v1/experience` payload that returns either placements
    ///     or layouts based on `rokt-experience-type` header
    /// - Parameters:
    ///   - params: A string dictionary containing the parameters that should be displayed in the widget
    ///   - roktTagId: The tag id provided by Rokt, associated with the client's account
    ///   - successPlacement: Function to execute after a successfull call to the API. Returns timeout, delay and fonts.
    ///         Executed if placements is returned. `rokt-experience-type` is
    ///         either nonexistent or equal to `placements`
    ///   - successLayout: Function to execute after a successfull call to the API. Returns timeout, delay and fonts.
    ///         Executed if DCUI layouts is returned. Executed if placements is returned. `rokt-experience-type` is
    ///         either nonexistent or equal to `layouts`
    ///   - trackingConsent: Whether the user wants to be tracked via `ATTrackingManager`
    ///   - failure: Function to execute after an unseccessfull call to the API
    static func getExperienceData(
        params: [String: Any],
        roktTagId: String,
        trackingConsent: UInt?,
        pageIdentifier: String?,
        onRequestStart: (() -> Void)?,
        successLayout: ((String?) -> Void)? = nil,
        failure: ((Error, Int?, String) -> Void)? = nil
    ) {
        var headers = getDefaultHeaders(tagId: roktTagId, requestingLayouts: true)
        if let trackingConsent = trackingConsent {
            headers[headerTrackingConsent] = "\(trackingConsent)"
        }

        if let pageIdentifier = pageIdentifier {
            headers[Self.headerPageIdentifierKey] = pageIdentifier
        }

        let updatedParams = RoktAPIHelper.addRealtimeEventsIfPresent(to: params)

        headers[layoutsSchemaVersionHeader] = layoutsSchemaVersion

        NetworkingHelper.performPost(
            url: experiencesResourceURL,
            body: updatedParams,
            headers: headers,
            extraErrorCheck: true,
            onRequestStart: onRequestStart,
            success: { (_, data, _) in
                if let data, let successLayout {
                    do {
                        successLayout(
                            String(data: data, encoding: .utf8))
                    } catch let error {
                        RoktLogger.shared.debug(parsingLayoutError + error.localizedDescription)
                        RoktAPIHelper.sendDiagnostics(message: validationDiagnosticCode,
                                                      callStack: parsingLayoutError + error.localizedDescription)
                        failure?(error, 200, parsingLayoutError + error.localizedDescription)
                    }
                }
            },
            failure: failure)
    }

    /// Rokt timings collection API call
    ///
    /// - Parameters:
    ///   - timingsRequest: TimingsRequest object of containing metadata and collected timings
    ///   - sessionId: Session identifier for the request
    ///   - selectionId: Selection identifier (UUID) to be sent as x-rokt-trace-id header
    class func sendTimings(timingsRequest: TimingsRequest,
                           sessionId: String?,
                           selectionId: String) {
        guard let tagId = Rokt.shared.roktImplementation.roktTagId else { return }

        let timingsHeaders = getTimingsRequestHeaders(tagId: tagId, timingsRequest: timingsRequest, selectionId: selectionId)

        NetworkingHelper.performPost(url: timingsResourceUrl,
                                     body: timingsRequest.toDictionary(),
                                     headers: timingsHeaders,
                                     failure: { (error, statusCode, response) in
                                        let callStack = String(format: timingsAPIFailureMsg,
                                                               response,
                                                               String(describing: statusCode),
                                                               error.localizedDescription)
                                        RoktAPIHelper.sendDiagnostics(
                                            message: timingsDiagnosticCode,
                                            callStack: callStack,
                                            sessionId: sessionId)
                                        RoktLogger.shared.verbose(callStack) })
    }

    /// Initialize a purchase for Shoppable Ads via the cart API.
    ///
    /// - Parameters:
    ///   - upsellItems: The items being purchased
    ///   - shippingAttributes: Shipping address for the order
    ///   - success: Callback with the parsed response
    ///   - failure: Callback with error details
    class func initializePurchase(upsellItems: [UpsellItem],
                                  shippingAttributes: ShippingAttributes,
                                  success: ((InitializePurchaseResponse) -> Void)? = nil,
                                  failure: ((Error, Int?, String) -> Void)? = nil) {
        guard let tagId = Rokt.shared.roktImplementation.roktTagId else {
            let message = "Missing Rokt tag ID for initialize-purchase request"
            let error = NSError(
                domain: "RoktSDK",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: message])
            failure?(error, nil, message)
            return
        }

        let totalUpsellPrice = upsellItems.reduce(Decimal.zero) { $0 + $1.totalPrice }
        let currency = upsellItems.first?.currency ?? "USD"
        let fulfillmentDetails = FulfillmentDetails(shippingAttributes: shippingAttributes)

        let request = InitializePurchaseRequest(
            totalUpsellPrice: totalUpsellPrice,
            currency: currency,
            upsellItems: upsellItems,
            fulfillmentDetails: fulfillmentDetails)

        let headers = getDefaultHeaders(tagId: tagId)

        NetworkingHelper.performPost(
            url: "\(baseURL)/v1/cart/initialize-purchase",
            body: request.toDictionary(),
            headers: headers,
            success: { _, data, _ in
                guard let data, let successCallback = success else { return }
                do {
                    let response = try JSONDecoder().decode(
                        InitializePurchaseResponse.self,
                        from: data)
                    successCallback(response)
                } catch {
                    let parseError = NSError(
                        domain: "RoktSDK",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to parse initialize-purchase response"])
                    failure?(parseError, 200, "Failed to parse response")
                }
            },
            failure: { error, statusCode, response in
                let callStack = String(
                    format: "response: %@, statusCode: %@, error: %@",
                    response,
                    String(describing: statusCode),
                    error.localizedDescription)
                RoktAPIHelper.sendDiagnostics(
                    message: "[INITIALIZE_PURCHASE]",
                    callStack: callStack)
                RoktLogger.shared.verbose(callStack)
                failure?(error, statusCode, response)
            })
    }
}
