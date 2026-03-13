import Foundation

internal class RoktNetWorkAPI {
    private static let BE_HEADER_PAGE_IDENTIFIER_KEY = "rokt-page-identifier"
    /// Rokt initialize API call
    ///
    /// - Parameters:
    ///   - roktTagId: The tag id provided by Rokt, associated with the client's account
    ///   - success: Function to execute after a successfull call to the API. Returns timeout, delay and fonts
    ///   - failure: Function to execute after an unseccessfull call to the API
    class func initialize(roktTagId: String,
                          success: ((InitRespose) -> Void)? = nil,
                          failure: ((Error, Int?, String) -> Void)? = nil) {
        NetworkingHelper.performGet(url: kInitResourceUrl,
                                    params: nil,
                                    headers: [
                                        BE_TAG_ID_KEY: roktTagId,
                                        BE_SDK_FRAMEWORK_TYPE: Rokt.shared.roktImplementation.frameworkType.toString
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
        if let clientTimeout = initData[BE_CLIENT_TIMEOUT_KEY] as? Double,
           let defaultLaunchDelay = initData[BE_DEFAULT_LAUNCH_DELAY_KEY] as? Double,
           let successCallback = success {
            let roktTrackingStatus = initData[BE_ROKT_FLAG_KEY] as? Bool ?? true
            var fonts = [FontModel]()

            if let fontDicts = initData[BE_FONTS_KEY] as? [[String: String]] {
                fonts = fontDicts.compactMap({ (fontDict) -> FontModel? in
                    FontModel(fontDict: fontDict)
                })
            }

            let clientSessionTimeout =
                initData[BE_CLIENT_SESSION_TIMEOUT_KEY] as? Double
            let shouldLogFontHappyPath =
                initData[BE_LOG_FONT_KEY] as? Bool ?? false
            let shouldUseFontRegisterWithUrl =
                initData[BE_USE_FONT_REGISTERY_URL_KEY] as? Bool ?? false
            var featureFlags = [String: FeatureFlagItem]()
            do {
                if let featureFlagItemsData =
                    initData[BE_FEATURE_FLAG_KEY],
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
                    fontLogId: kFullFontLogCode3)

                FontManager.registerFont(font: font, fileUrl: downloadedFileLocalURL, isDownloaded: true)
                onDownloadComplete(isLastFont)
            } else if let downloadError = downloadResponse.downloadError {
                if retryCount < kMaxRetries && NetworkingHelper.retriableResponse(
                    error: downloadError,
                    code: downloadResponse.httpURLResponse?.statusCode) {

                    // Log FFL4
                    FontManager.sendFullFontLogs(
                        "Retry for font file \(destinationURL) error on download \(downloadError)",
                        fontLogId: kFullFontLogCode4)

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
                    let callstack = "\(kAPIFontErrorMessage) \(font.url), " +
                        "error: \(String(describing: downloadResponse.downloadError.debugDescription))"

                    RoktAPIHelper.sendDiagnostics(message: kAPIFontErrorCode, callStack: callstack)
                    RoktLogger.shared.verbose(callstack)
                    onDownloadComplete(isLastFont)
                }
            }

            if isLastFont {
                NotificationCenter.default.post(Notification(name: Notification.Name(kFinishedDownloadingFonts)))
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
        NetworkingHelper.performPost(urlString: kEventResourceUrl,
                                     bodyArray: paramsArray,
                                     headers: getDefaultHeaders(tagId: tagId),
                                     success: { (_, _, _) in
                                        success?()
                                     },
                                     failure: { (error, statusCode, response) in
                                        // Don't report diagnostics for 429 (Too Many Requests) status code
                                        if let code = statusCode, code != 429 {
                                            let callStack = String(format: kEventAPIFailureMsg,
                                                                   response,
                                                                   String(describing: statusCode),
                                                                   error.localizedDescription)

                                            RoktAPIHelper.sendDiagnostics(
                                                message: kAPIEventErrorCode,
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
        NetworkingHelper.performPost(url: kDiagnosticsResourceUrl,
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
        var headers: [String: String] = [BE_TAG_ID_KEY: tagId]

        if let sessionId = getSessionId(requestingLayouts: requestingLayouts), !sessionId.isEmpty {
            headers[BE_HEADER_SESSION_ID_KEY] = sessionId
        }

        headers[BE_SDK_FRAMEWORK_TYPE] = Rokt.shared.roktImplementation.frameworkType.toString

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
        headers[BE_HEADER_INTEGRATION_TYPE_KEY] = kTimingsSDKType
        headers["x-rokt-trace-id"] = selectionId

        if let pageInstanceGuid = timingsRequest.pageInstanceGuid {
            headers[BE_HEADER_PAGE_INSTANCE_GUID_KEY] = pageInstanceGuid
        }

        if let pageId = timingsRequest.pageId {
            headers[BE_HEADER_PAGE_ID_KEY] = pageId
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
            headers[BE_TRACKING_CONSENT] = "\(trackingConsent)"
        }

        if let pageIdentifier = pageIdentifier {
            headers[Self.BE_HEADER_PAGE_IDENTIFIER_KEY] = pageIdentifier
        }

        let updatedParams = RoktAPIHelper.addRealtimeEventsIfPresent(to: params)

        headers[kLayoutsSchemaVersionHeader] = kLayoutsSchemaVersion

        NetworkingHelper.performPost(
            url: kExperiencesResourceURL,
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
                        RoktLogger.shared.debug(kParsingLayoutError + error.localizedDescription)
                        RoktAPIHelper.sendDiagnostics(message: kValidationErrorCode,
                                                      callStack: kParsingLayoutError + error.localizedDescription)
                        failure?(error, 200, kParsingLayoutError + error.localizedDescription)
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

        NetworkingHelper.performPost(url: kTimingsResourceUrl,
                                     body: timingsRequest.toDictionary(),
                                     headers: timingsHeaders,
                                     failure: { (error, statusCode, response) in
                                        let callStack = String(format: kTimingsAPIFailureMsg,
                                                               response,
                                                               String(describing: statusCode),
                                                               error.localizedDescription)
                                        RoktAPIHelper.sendDiagnostics(
                                            message: kAPITimingsErrorCode,
                                            callStack: callStack,
                                            sessionId: sessionId)
                                        RoktLogger.shared.verbose(callStack) })
}
}
