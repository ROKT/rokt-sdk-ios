import Foundation
import UIKit
internal import RoktUXHelper

/// Helper class to request and process Rokt api response details
internal class RoktAPIHelper {
    private static let errorAdditionalKey = "additionalInformation"
    private static let errorSessionIdKey = "sessionId"
    private static let errorCampaignIdKey = "campaignId"
    static let errorCodeDiagnosticKey = "code"
    static let errorStackTraceDiagnosticKey = "stackTrace"
    static let errorSeverityDiagnosticKey = "severity"

    /// Rokt donwload fonts API call
    ///
    /// - Parameters:
    ///   - fonts: The fonts that should be downloaded and installed to be used in the widget
    ///   - onFontDownloadComplete - Callback to notify when the font download finishes
    class func downloadFonts(_ fonts: [FontModel], _ onFontDownloadComplete: @escaping () -> Void) {
        FontManager.downloadFonts(fonts, onFontDownloadComplete)
    }

    /// Rokt event API call — routes through the transactions events client.
    ///
    /// - Parameters:
    ///   - eventRequest: The EventRequest related to the event
    class func sendEvent(eventRequest: EventRequest,
                         success: (() -> Void)? = nil) {
        guard Rokt.shared.roktImplementation.roktTagId != nil,
              Rokt.shared.roktImplementation.processedEvents?.insertProcessedEvent(eventRequest) == true
        else { return }

        EventQueue.call(event: eventRequest) { events in
            Rokt.shared.roktImplementation.dispatchTxnEvents(
                events.compactMap { TxnEventMapper.event(from: $0) }
            )
            success?()
        }
    }

    /// Rokt diagnostics API call
    ///
    /// - Parameters:
    ///   - message: The message related to the error
    ///   - callStack: The call stack or more information related to the error
    ///   - severity: severity of the error
    ///   - success: Function to execute after a successfull call to the API
    ///   - failure: Function to execute after an unseccessfull call to the API
    class func sendDiagnostics(message: String,
                               callStack: String,
                               severity: Severity = .error,
                               sessionId: String? = nil,
                               campaignId: String? = nil,
                               additionalInfo: [String: Any] = [:],
                               success: (() -> Void)? = nil,
                               failure: ((Error, Int?, String) -> Void)? = nil) {
        guard Rokt.shared.roktImplementation.roktTagId != nil else { return }

        var params: [String: Any] = [errorCodeDiagnosticKey: message,
                                     errorStackTraceDiagnosticKey: callStack,
                                     errorSeverityDiagnosticKey: severity.rawValue]
        var additional: [String: Any] = additionalInfo
        if let sessionId = sessionId {
            additional[errorSessionIdKey] = sessionId
        }
        if let campaignId = campaignId {
            additional[errorCampaignIdKey] = campaignId
        }
        if !additional.isEmpty {
            params[errorAdditionalKey] = additional
        }
        if isMock() {
            RoktMockAPI.sendDiagnostics(params: params, success: success, failure: failure)
        } else {
            RoktNetWorkAPI.sendDiagnostics(params: params, success: success, failure: failure)
        }
    }

    /// Initialize a purchase for Shoppable Ads.
    ///
    /// - Parameters:
    ///   - upsellItems: Items being purchased
    ///   - shippingAttributes: Shipping address
    ///   - returnURL: Optional redirect success URL (e.g. built-in PayPal)
    ///   - cancelURL: Optional redirect cancel URL (e.g. built-in PayPal)
    ///   - paymentMethodType: Optional cart body `paymentMethodType` (PascalCase cart-api
    ///     `PaymentMethodType` member name, e.g. `"Card"`, `"ApplePay"`, `"Paypal"`, `"Afterpay"`).
    ///   - paymentProvider: Optional cart body `paymentProvider` (PascalCase, e.g. `"Stripe"`,
    ///     `"PayPal"`, `"Card"`, `"Afterpay"`, `"ApplePay"`).
    ///   - success: Callback with the initialize-purchase response
    ///   - failure: Callback with error details
    class func initializePurchase(upsellItems: [UpsellItem],
                                  shippingAttributes: ShippingAttributes,
                                  returnURL: String? = nil,
                                  cancelURL: String? = nil,
                                  paymentMethodType: String? = nil,
                                  paymentProvider: String? = nil,
                                  success: ((InitializePurchaseResponse) -> Void)? = nil,
                                  failure: ((Error, Int?, String) -> Void)? = nil) {
        if isMock() {
            RoktMockAPI.initializePurchase(upsellItems: upsellItems,
                                           shippingAttributes: shippingAttributes,
                                           returnURL: returnURL,
                                           cancelURL: cancelURL,
                                           paymentMethodType: paymentMethodType,
                                           paymentProvider: paymentProvider,
                                           success: success,
                                           failure: failure)
        } else {
            RoktNetWorkAPI.initializePurchase(upsellItems: upsellItems,
                                              shippingAttributes: shippingAttributes,
                                              returnURL: returnURL,
                                              cancelURL: cancelURL,
                                              paymentMethodType: paymentMethodType,
                                              paymentProvider: paymentProvider,
                                              success: success,
                                              failure: failure)
        }
    }

    /// Rokt forward-payment API call
    ///
    /// - Parameters:
    ///   - request: Purchase request payload built from the CartItemForwardPayment event
    ///   - success: Callback with the parsed response
    ///   - failure: Callback with error details
    class func forwardPayment(request: PurchaseRequest,
                              success: ((PurchaseResponse) -> Void)? = nil,
                              failure: ((Error, Int?, String) -> Void)? = nil) {
        if isMock() {
            RoktMockAPI.forwardPayment(request: request,
                                       success: success,
                                       failure: failure)
        } else {
            RoktNetWorkAPI.forwardPayment(request: request,
                                          success: success,
                                          failure: failure)
        }
    }

    private class func isMock() -> Bool {
        return config.environment == .Mock
    }

    /// Rokt timings collection API call
    ///
    /// - Parameters:
    ///   - timingsRequest: TimingsRequest object of containing metadata and collected timings
    ///   - sessionId: Session identifier for the request
    ///   - selectionId: Selection identifier (UUID) to be sent as x-rokt-trace-id header
    class func sendTimings(_ timingsRequest: TimingsRequest,
                           sessionId: String?,
                           selectionId: String) {
        guard Rokt.shared.roktImplementation.roktTagId != nil else { return }

        if isMock() {
            RoktMockAPI.sendTimings(timingsRequest: timingsRequest, selectionId: selectionId)
        } else {
            RoktNetWorkAPI.sendTimings(timingsRequest: timingsRequest, sessionId: sessionId, selectionId: selectionId)
        }
    }

    /// Rokt timing events collection API call (performance metrics)
    ///
    /// - Parameters:
    ///   - timingEventsRequest: TimingEventsRequest object containing metadata and collected timing metrics
    ///   - sessionId: Session identifier for the request
    ///   - selectionId: Selection identifier (UUID) to be sent as x-rokt-trace-id header
    class func sendTimingEvents(_ timingEventsRequest: TimingEventsRequest,
                                sessionId: String?,
                                selectionId: String) {
        guard Rokt.shared.roktImplementation.roktTagId != nil else { return }

        if isMock() {
            RoktMockAPI.sendTimingEvents(timingEventsRequest: timingEventsRequest, selectionId: selectionId)
        } else {
            RoktNetWorkAPI.sendTimingEvents(timingEventsRequest: timingEventsRequest,
                                            sessionId: sessionId,
                                            selectionId: selectionId)
        }
    }
}
