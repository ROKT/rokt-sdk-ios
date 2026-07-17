import Foundation

// MARK: - URL constants (internal — also used by test mocks)

let mobileAPIPathPrefix = "rokt-mobile"

var diagnosticsResourceURL: String { "\(baseURL)/\(mobileAPIPathPrefix)/v1/diagnostics" }
var timingsResourceURL: String { "\(baseURL)/\(mobileAPIPathPrefix)/v1/timings" }
var timingsEventsResourceURL: String { "\(baseURL)/\(mobileAPIPathPrefix)/v1/timings/events" }
var initializePurchaseResourceURL: String { "\(baseURL)/\(mobileAPIPathPrefix)/v1/cart/initialize-purchase" }
var purchaseResourceURL: String { "\(baseURL)/\(mobileAPIPathPrefix)/v1/cart/purchase" }

// MARK: - Header keys (internal — used by test mocks)

let headerPageInstanceGuidKey = "rokt-page-instance-guid"
let headerPageIdKey = "rokt-page-id"

internal class RoktNetWorkAPI {
    // MARK: - API failure messages

    private static let timingsAPIFailureMsg = "response: %@, statusCode: %@, error: %@"

    // MARK: - Header keys

    private static let headerSessionIdKey = "rokt-session-id"
    private static let headerIntegrationTypeKey = "rokt-integration-type"

    // MARK: - Other constants

    private static let headerTagIdKey = "rokt-tag-id"
    private static let headerSdkFrameworkType = "rokt-sdk-framework-type"
    private static let fontErrorMessage = "Error downloading font: "
    private static let timingsDiagnosticCode = "[TIMINGS]"
    private static let timingsSdkType = "msdk"
    private static let fullFontLogCode3 = "[FFL003]"
    private static let fullFontLogCode4 = "[FFL004]"

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
            requestTimeout: TimeInterval(exactly: RoktInternalImplementation.defaultFontTimeout)!) { downloadResponse in
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
                    // Best-effort: mark for diagnostics, don't un-initialise.
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
        NetworkingHelper.performPost(url: diagnosticsResourceURL,
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
    /// - Returns: A dictionary containing the default HTTP headers.
    private class func getDefaultHeaders(tagId: String) -> [String: String] {
        var headers: [String: String] = [headerTagIdKey: tagId]

        if let sessionId = Rokt.shared.roktImplementation.sessionManager.getCurrentSessionIdWithoutExpiring(),
           !sessionId.isEmpty {
            headers[headerSessionIdKey] = sessionId
        }

        headers[headerSdkFrameworkType] = Rokt.shared.roktImplementation.frameworkType.toString

        return headers
    }

    private class func getTimingsRequestHeaders(tagId: String,
                                                pageInstanceGuid: String?,
                                                pageId: String?,
                                                selectionId: String) -> [String: String] {
        var headers: [String: String] = getDefaultHeaders(tagId: tagId)

        // Enrich default headers with integrationType, pageInstanceGuid, pageId, and selectionId
        headers[headerIntegrationTypeKey] = timingsSdkType
        headers["x-rokt-trace-id"] = selectionId

        if let pageInstanceGuid {
            headers[headerPageInstanceGuidKey] = pageInstanceGuid
        }

        if let pageId {
            headers[headerPageIdKey] = pageId
        }

        return headers
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

        let timingsHeaders = getTimingsRequestHeaders(tagId: tagId,
                                                      pageInstanceGuid: timingsRequest.pageInstanceGuid,
                                                      pageId: timingsRequest.pageId,
                                                      selectionId: selectionId)

        NetworkingHelper.performPost(url: timingsResourceURL,
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

    /// Rokt timing events collection API call (performance metrics)
    ///
    /// - Parameters:
    ///   - timingEventsRequest: TimingEventsRequest object containing metadata and collected timing metrics
    ///   - sessionId: Session identifier for the request
    ///   - selectionId: Selection identifier (UUID) to be sent as x-rokt-trace-id header
    class func sendTimingEvents(timingEventsRequest: TimingEventsRequest,
                                sessionId: String?,
                                selectionId: String) {
        guard let tagId = Rokt.shared.roktImplementation.roktTagId else { return }

        let timingsHeaders = getTimingsRequestHeaders(tagId: tagId,
                                                      pageInstanceGuid: timingEventsRequest.pageInstanceGuid,
                                                      pageId: timingEventsRequest.pageId,
                                                      selectionId: selectionId)

        NetworkingHelper.performPost(url: timingsEventsResourceURL,
                                     body: timingEventsRequest.toDictionary(),
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
    ///   - returnURL: Optional redirect success URL for payment flows that need it
    ///   - cancelURL: Optional redirect cancel URL for payment flows that need it
    ///   - paymentMethodType: Optional cart body `paymentMethodType` (PascalCase cart-api
    ///     `PaymentMethodType` member name, e.g. `"Card"`, `"ApplePay"`, `"Paypal"`, `"Afterpay"`).
    ///   - paymentProvider: Optional cart body `paymentProvider` (PascalCase, e.g. `"Stripe"`,
    ///     `"PayPal"`, `"Card"`, `"Afterpay"`, `"ApplePay"`).
    ///   - success: Callback with the parsed response
    ///   - failure: Callback with error details
    class func initializePurchase(upsellItems: [UpsellItem],
                                  shippingAttributes: ShippingAttributes,
                                  returnURL: String? = nil,
                                  cancelURL: String? = nil,
                                  paymentMethodType: String? = nil,
                                  paymentProvider: String? = nil,
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
            fulfillmentDetails: fulfillmentDetails,
            returnURL: returnURL,
            cancelURL: cancelURL,
            paymentMethodType: paymentMethodType,
            paymentProvider: paymentProvider)

        let headers = getDefaultHeaders(tagId: tagId)

        NetworkingHelper.performPost(
            url: initializePurchaseResourceURL,
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

    /// Forward a purchase to the Rokt Cart API on behalf of the partner.
    ///
    /// - Parameters:
    ///   - request: Purchase request payload built from the CartItemForwardPayment event
    ///   - success: Callback with the decoded response (may still report a business failure via `response.success`)
    ///   - failure: Callback with error details for HTTP / network / decode failures
    class func forwardPayment(request: PurchaseRequest,
                              success: ((PurchaseResponse) -> Void)? = nil,
                              failure: ((Error, Int?, String) -> Void)? = nil) {
        guard let tagId = Rokt.shared.roktImplementation.roktTagId else {
            let message = "Missing Rokt tag ID for forward-payment request"
            let error = NSError(
                domain: "RoktSDK",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: message])
            failure?(error, nil, message)
            return
        }

        let headers = getDefaultHeaders(tagId: tagId)

        NetworkingHelper.performPost(
            url: purchaseResourceURL,
            body: request.toDictionary(),
            headers: headers,
            success: { _, data, _ in
                guard let data, let successCallback = success else { return }
                do {
                    let response = try JSONDecoder().decode(
                        PurchaseResponse.self,
                        from: data)
                    successCallback(response)
                } catch {
                    let parseError = NSError(
                        domain: "RoktSDK",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to parse forward-payment response"])
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
                    message: "[FORWARD_PAYMENT]",
                    callStack: callStack)
                RoktLogger.shared.verbose(callStack)
                failure?(error, statusCode, response)
            })
    }
}
