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
    private static let eventsLoggingEnabled = false

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
            params[Self.viewNameKey] = vName
        }

        if !privacyControlPayload.isEmpty {
            params[Self.privacyControlKey] = privacyControlPayload
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
        if Self.eventsLoggingEnabled {
            events.map {
                $0.filter { element in
                    [sessionIdKey,
                     parentGuidKey,
                     pageInstanceGuidKey,
                     eventTypeKey,
                     metadataKey].contains(element.key)
                }
            }.compactMap {
                try? JSONSerialization.data(withJSONObject: $0, options: [])
            }.map {
                String(data: $0, encoding: .utf8)
            }.forEach {
                NSLog("RoktEventLog: \($0 ?? "")")
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
                if Self.eventsLoggingEnabled {
                    NSLog(event.getLog())
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

        var params: [String: Any] = [Self.errorCodeDiagnosticKey: message,
                                     Self.errorStackTraceDiagnosticKey: callStack,
                                     Self.errorSeverityDiagnosticKey: severity.rawValue]
        var additional: [String: Any] = additionalInfo
        if let sessionId = sessionId {
            additional[Self.errorSessionIdKey] = sessionId
        }
        if let campaignId = campaignId {
            additional[Self.errorCampaignIdKey] = campaignId
        }
        if !additional.isEmpty {
            params[Self.errorAdditionalKey] = additional
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
    ///   - success: Callback with the initialize-purchase response
    ///   - failure: Callback with error details
    class func initializePurchase(upsellItems: [UpsellItem],
                                  shippingAttributes: ShippingAttributes,
                                  success: ((InitializePurchaseResponse) -> Void)? = nil,
                                  failure: ((Error, Int?, String) -> Void)? = nil) {
        if isMock() {
            RoktMockAPI.initializePurchase(upsellItems: upsellItems,
                                           shippingAttributes: shippingAttributes,
                                           success: success,
                                           failure: failure)
        } else {
            RoktNetWorkAPI.initializePurchase(upsellItems: upsellItems,
                                              shippingAttributes: shippingAttributes,
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
