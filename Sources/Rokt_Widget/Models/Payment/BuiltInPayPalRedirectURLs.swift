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

/// Validates a bare URL scheme string and optional `Info.plist` registration (skipped under XCTest so unit tests can set a scheme without a host app URL type).
enum PayPalRedirectURLSchemeValidator {
    /// When `false` (e.g. XCTest loaded), only ``isValidBareScheme`` is enforced.
    static var shouldValidateAgainstInfoPlist: Bool {
        NSClassFromString("XCTestCase") == nil
    }

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
