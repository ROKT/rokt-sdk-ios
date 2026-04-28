import Foundation

/// Fixed hosts for built-in PayPal redirect URLs, composed as `\(bareScheme)://\(host)` (same pattern as the Stripe payment extension’s `rokt-payment-return` host).
enum BuiltInPayPalRedirectURLs {
    static let returnHost = "rokt-paypal-return"
    static let cancelHost = "rokt-paypal-cancel"

    static func returnAndCancelURLs(forBareScheme scheme: String) -> (returnURL: String, cancelURL: String) {
        let s = scheme.trimmingCharacters(in: .whitespacesAndNewlines)
        return ("\(s)://\(returnHost)", "\(s)://\(cancelHost)")
    }
}

/// Validates a bare URL scheme string and optional `Info.plist` registration.
///
/// Info.plist registration is **not** checked when:
/// - XCTest is loaded (unit tests), or
/// - **DEBUG** builds of known Rokt sample apps (`com.rokt.ios-example`, `com.rokt.PaymentSampleApp`, or CocoaPods-generated Rokt example bundles), so sample projects can use placeholder schemes without matching `CFBundleURLSchemes`.
///
/// **Release** builds always enforce `CFBundleURLTypes` / `CFBundleURLSchemes` for non-empty schemes.
enum PayPalRedirectURLSchemeValidator {
    /// When `false`, only ``isValidBareScheme`` is enforced (no `Info.plist` URL-type check).
    static var shouldValidateAgainstInfoPlist: Bool {
        if NSClassFromString("XCTestCase") != nil {
            return false
        }
        #if DEBUG
        if isKnownRoktSampleApplicationBundle {
            return false
        }
        #endif
        return true
    }

    #if DEBUG
    private static var isKnownRoktSampleApplicationBundle: Bool {
        guard let id = Bundle.main.bundleIdentifier else { return false }
        if id == "com.rokt.ios-example" || id == "com.rokt.PaymentSampleApp" {
            return true
        }
        // CocoaPods example target: `org.cocoapods.<ProductName>`
        if id.hasPrefix("org.cocoapods."), id.localizedCaseInsensitiveContains("rokt") {
            return true
        }
        return false
    }
    #endif

    static func isValidBareScheme(_ scheme: String) -> Bool {
        let s = scheme.trimmingCharacters(in: .whitespacesAndNewlines)
        return !s.isEmpty && !s.contains("://") && !s.contains("/")
    }

    static func isSchemeRegistered(_ scheme: String, in bundle: Bundle) -> Bool {
        let target = scheme.lowercased()
        guard let urlTypes = bundle.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]] else {
            return false
        }
        for entry in urlTypes {
            if let schemes = entry["CFBundleURLSchemes"] as? [String],
               schemes.map({ $0.lowercased() }).contains(target) {
                return true
            }
        }
        return false
    }
}
