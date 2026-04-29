import Foundation
import UIKit
internal import RoktUXHelper

/// Helper class to request and process Rokt api response details
internal class RoktAPIHelper {
    private static let viewNameKey = "pageIdentifier"
    private static let errorAdditionalKey = "additionalInformation"
    private static let errorSessionIdKey = "sessionId"
    private static let errorCampaignIdKey = "campaignId"
    static let errorCodeDiagnosticKey = "code"
    static let errorStackTraceDiagnosticKey = "stackTrace"
    static let errorSeverityDiagnosticKey = "severity"
    private static let privacyControlKey = "privacyControl"

    /// Rokt initialize API call
    ///
    /// - Parameters:
    ///   - roktTagId: The tag id provided by Rokt, associated with the client's account
    ///   - success: Function to execute after a successfull call to the API.
    ///              Returns timeout, delay, session timeout and fonts
    ///   - failure: Function to execute after an unseccessfull call to the API
    class func initialize(roktTagId: String,
                          success: ((InitRespose) -> Void)? = nil,
                          failure: ((Error, Int?, String) -> Void)? = nil) {
        if isMock() {
            RoktMockAPI.initialize(roktTagId: roktTagId, success: success, failure: failure)
        } else {
            RoktNetWorkAPI.initialize(roktTagId: roktTagId, success: success, failure: failure)
        }
    }

    /// Rokt donwload fonts API call
    ///
    /// - Parameters:
    ///   - fonts: The fonts that should be downloaded and installed to be used in the widget
    ///   - onFontDownloadComplete - Callback to notify when the font download finishes
    class func downloadFonts(_ fonts: [FontModel], _ onFontDownloadComplete: @escaping () -> Void) {
        FontManager.downloadFonts(fonts, onFontDownloadComplete)
    }

    /// Rokt Placement API call
    ///
    /// - Parameters:
    ///   - viewName: The name that should be displayed in the widget
    ///   - attributes: A string dictionary containing the parameters that should be displayed in the widget
    ///   - roktTagId: The tag id provided by Rokt, associated with the client's account
    ///   - selectionId: The selection id for the request
    ///   - successPlacement: Function to execute after a successfull PLACEMENT call to the API
    ///   - successLayout: Function to execute after a successfull LAYOUTS call to the API
    ///   - failure: Function to execute after an unseccessfull call to the API
    class func getExperienceData(viewName: String?,
                                 attributes: [String: String],
                                 roktTagId: String,
                                 selectionId: String,
                                 trackingConsent: UInt?,
                                 config: RoktConfig?,
                                 onRequestStart: (() -> Void)?,
                                 successLayout: ((String?) -> Void)? = nil,
                                 failure: ((Error, Int?, String) -> Void)? = nil) {
        // extract the privacy KVPs BEFORE sanitising `attributes`
        let privacyControlPayload = getPrivacyControlPayload(attributes: attributes)
        let sanitisedAttributes = removePrivacyControlAttributes(attributes: attributes)

        // extract the pageInit timestamp, if available
        if let pageInitAttr = getPageInitData(attributes: attributes),
           let validPageInitTime = Rokt.shared.roktImplementation.processedTimingsRequests?.getValidPageInitTime(
               selectionId: selectionId,
               timeAsString: pageInitAttr
           ) {
            Rokt.shared.roktImplementation.processedTimingsRequests?.setPageInitTime(
                selectionId: selectionId,
                time: validPageInitTime
            )
        }

        let enrichedAttributes = AttributeEnrichment.shared.enrich(attributes: sanitisedAttributes, config: config)

        var params: [String: Any] = [
            attributesKey: enrichedAttributes
        ]

        if let vName = viewName {
            params[viewNameKey] = vName
        }

        if !privacyControlPayload.isEmpty {
            params[privacyControlKey] = privacyControlPayload
        }

        if isMock() {
            RoktMockAPI.getExperienceData(
                params: params,
                roktTagId: roktTagId,
                trackingConsent: trackingConsent,
                pageIdentifier: viewName,
                onRequestStart: onRequestStart,
                successLayout: successLayout,
                failure: failure
            )
        } else {
            RoktNetWorkAPI.getExperienceData(
                params: params,
                roktTagId: roktTagId,
                trackingConsent: trackingConsent,
                pageIdentifier: viewName,
                onRequestStart: onRequestStart,
                successLayout: successLayout,
                failure: failure
            )
        }
    }

    /// Rokt event API call
    ///
    /// - Parameters:
    ///   - evenRequest: The EventRequest related to the event
    ///   - success: Function to execute after a successfull call to the API
    ///   - failure: Function to execute after an unseccessfull call to the API
    class func sendEvents(events: [[String: Any]],
                          success: (() -> Void)? = nil,
                          failure: ((Error, Int?, String) -> Void)? = nil) {
        guard Rokt.shared.roktImplementation.roktTagId != nil else { return }
        let sessionId = events.first.flatMap { eventRequests in
            eventRequests.first { $0.key == sessionIdKey }?.value as? String
        }
        for event in events {
            if let eventType = event[eventTypeKey] as? String {
                RoktLogger.shared.debug("Sending event: \(eventType)")
            }
            if RoktLogger.shared.logLevel <= .verbose,
               let eventData = try? JSONSerialization.data(withJSONObject: event),
               let eventLog = String(data: eventData, encoding: .utf8) {
                RoktLogger.shared.verbose("RoktEventLog: \(eventLog)")
            }
        }
        if isMock() {
            RoktMockAPI.sendEvent(paramsArray: events, sessionId: sessionId,
                                  success: success, failure: failure)
        } else {
            RoktNetWorkAPI.sendEvent(paramsArray: events, sessionId: sessionId,
                                     success: success, failure: failure)
        }
    }

    /// Rokt event API call
    ///
    /// - Parameters:
    ///   - evenRequest: The EventRequest related to the event
    ///   - success: Function to execute after a successfull call to the API
    ///   - failure: Function to execute after an unseccessfull call to the API
    class func sendEvent(eventRequest: EventRequest,
                         success: (() -> Void)? = nil,
                         failure: ((Error, Int?, String) -> Void)? = nil) {
        guard Rokt.shared.roktImplementation.roktTagId != nil,
              Rokt.shared.roktImplementation.processedEvents?.insertProcessedEvent(eventRequest) == true
        else { return }

        EventQueue.call(event: eventRequest) { events in
            var eventsBody = [[String: Any]]()
            for event in events {
                eventsBody.append(event.getParams)
                RoktLogger.shared.debug("Sending event: \(event.eventType.rawValue)")
                if RoktLogger.shared.logLevel <= .verbose {
                    RoktLogger.shared.verbose(event.getLog())
                }
            }

            if isMock() {
                RoktMockAPI.sendEvent(paramsArray: eventsBody, sessionId: eventRequest.sessionId,
                                      success: success, failure: failure)
            } else {
                RoktNetWorkAPI.sendEvent(paramsArray: eventsBody, sessionId: eventRequest.sessionId,
                                         success: success, failure: failure)
            }
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
    ///   - paymentMethod: Optional cart body `payment_method` (e.g. `"PAYPAL"` for built-in PayPal)
    ///   - paymentProvider: Optional cart body `payment_provider` (e.g. `"PAYPAL"` for built-in PayPal)
    ///   - success: Callback with the initialize-purchase response
    ///   - failure: Callback with error details
    class func initializePurchase(upsellItems: [UpsellItem],
                                  shippingAttributes: ShippingAttributes,
                                  returnURL: String? = nil,
                                  cancelURL: String? = nil,
                                  paymentMethod: String? = nil,
                                  paymentProvider: String? = nil,
                                  success: ((InitializePurchaseResponse) -> Void)? = nil,
                                  failure: ((Error, Int?, String) -> Void)? = nil) {
        if isMock() {
            RoktMockAPI.initializePurchase(upsellItems: upsellItems,
                                           shippingAttributes: shippingAttributes,
                                           returnURL: returnURL,
                                           cancelURL: cancelURL,
                                           paymentMethod: paymentMethod,
                                           paymentProvider: paymentProvider,
                                           success: success,
                                           failure: failure)
        } else {
            RoktNetWorkAPI.initializePurchase(upsellItems: upsellItems,
                                              shippingAttributes: shippingAttributes,
                                              returnURL: returnURL,
                                              cancelURL: cancelURL,
                                              paymentMethod: paymentMethod,
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
}
