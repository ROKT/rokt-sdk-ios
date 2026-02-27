import Foundation

internal class RoktMockAPI {

    class func initialize(roktTagId: String,
                          success: ((InitRespose) -> Void)? = nil,
                          failure: ((Error, Int?, String) -> Void)? = nil) {
        success?(InitRespose(timeout: 8000, delay: 0,
                             clientSessionTimeout: 1800000,
                             fonts: [],
                             featureFlags: InitFeatureFlags(
                                 roktTrackingStatus: true,
                                 shouldLogFontHappyPath: true,
                                 shouldUseFontRegisterWithUrl: true,
                                 featureFlags: ["mobile-sdk-use-partner-events": FeatureFlagItem(match: true),
                                                "mobile-sdk-use-bounding-box": FeatureFlagItem(match: true),
                                                "mobile-sdk-use-timings-api": FeatureFlagItem(match: true),
                                                "mobile-sdk-use-sdk-cache": FeatureFlagItem(match: true)]
                             )))
    }

    class func downloadFonts(_ fonts: [FontModel]) {}

    class func getExperienceData(
        params: [String: Any],
        roktTagId: String,
        trackingConsent: UInt?,
        pageIdentifier: String?,
        onRequestStart: (() -> Void)?,
        successLayout: ((String?) -> Void)? = nil,
        failure: ((Error, Int?, String) -> Void)? = nil
    ) {
        onRequestStart?()
        if let path = Bundle.main.path(forResource: getPlacementJsonName(roktTagId), ofType: "json") {
            do {
                successLayout?(
                    String(
                        data: try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe),
                        encoding: .utf8
                    )
                )
            } catch let error {
                RoktLogger.shared.debug("\(kParsingLayoutError) \(error)")
                RoktAPIHelper.sendDiagnostics(message: kValidationErrorCode,
                                              callStack: kParsingLayoutError + error.localizedDescription)
                successLayout?(nil)
            }
        } else {
            successLayout?(nil)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private class func getPlacementJsonName(_ roktTagId: String) -> String {
        switch roktTagId {
        case "2731619347947643042_3331d443712b433587bc4813b8ff1111": // Layout playground
            return "layout_playground"
        case "2731619347947643042_3331d443712b433587bc4813b8ff8213": // Layout overlay
            return "partner1_overlay"
        case "2731619347947643042_3331d443712b433587bc4813b8ff8214": // Layout overlay 1
            return "layout_overlay_1"
        case "2731619347947643042_3331d443712b433587bc4813b8ff8215": // Layout Carousel
            return "layout_carousel"
        case "2731619347947643042_3331d443712b433587bc4813b8ff8216": // Layout Grouped
            return "layout_grouped_distribution"
        case "2731619347947643042_3331d443712b433587bc48444333222": // Layout bottomSheet
            return "layout_bottomsheet"
        case "2731619347947643042_3331d443712b433587bc4813b8ff8300": // Layout embedded 1
            return "layout_embedded_1"
        case "2731619347947643042_3331d443712b433587bc4813b8ff8302": // Layout embedded 2
            return "layout_embedded_2"
        case "2731619347947643042_3331d443712b433587bc4813b8ff8453": // Layout multiple 1
            return "layout_multiple_1"
        case "2731619347947643042_3331d443712b433587bc4813b8ff8411": // Layout multiple 2
            return "layout_multiple_2"
        case "2731619347947643042_3331d443712b433587bc4813b8ff8777": // Layout embedded 4
            return "layout_embedded_4"
        default:
            return "placement_light_box" // Placement Lightbox
        }
    }

    class func sendEvent(paramsArray: [[String: Any]],
                         sessionId: String?,
                         success: (() -> Void)? = nil,
                         failure: ((Error, Int?, String) -> Void)? = nil) {
        do {
            let params = try JSONSerialization.data(withJSONObject: paramsArray, options: [])
            RoktLogger.shared.verbose(String(bytes: params, encoding: .utf8) ?? "")
        } catch {}
        success?()
    }

    class func sendDiagnostics(params: [String: Any],
                               success: (() -> Void)? = nil,
                               failure: ((Error, Int?, String) -> Void)? = nil) {
        do {
            let params = try JSONSerialization.data(withJSONObject: params, options: [])
            RoktLogger.shared.verbose(String(bytes: params, encoding: .utf8) ?? "")
        } catch {}
        success?()
    }

    class func sendTimings(timingsRequest: TimingsRequest, selectionId: String) {
        do {
            var requestData = timingsRequest.toDictionary()
            requestData["selectionId"] = selectionId
            let params = try JSONSerialization.data(withJSONObject: requestData, options: [])
            RoktLogger.shared.verbose(String(bytes: params, encoding: .utf8) ?? "")
        } catch {}
    }
}
