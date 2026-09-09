import Foundation
import os.log
import PassKit
import RoktContracts
import StripeApplePay
import UIKit

/// Rokt payment extension backed by Stripe.
///
/// Currently supports Apple Pay and Afterpay/Clearpay via Stripe SDKs.
/// Partners provide what they want to support at init time:
/// - `applePayMerchantId` only                       → Apple Pay (and card via Apple Pay sheet)
/// - `universalLinkReturnURL` or `urlScheme` only    → Afterpay
/// - `applePayMerchantId` plus one of those two      → all three methods
///
/// Prefer `universalLinkReturnURL` (an https URL under one of the host app's
/// associated domains) for Afterpay in production: iOS delivers a universal link
/// only to the app entitled for that domain, whereas custom URL schemes are not
/// exclusive to one app.
///
/// Returns `nil` if none of the three parameters is provided, if both
/// `urlScheme` and `universalLinkReturnURL` are provided, if the supplied
/// `urlScheme` is not registered under `CFBundleURLSchemes` in the host app's
/// `Info.plist`, or if `universalLinkReturnURL` is not a plain https URL.
public class RoktPaymentExtension: PaymentExtension {

    // MARK: - PaymentExtension Protocol Properties

    public let id: String = "rokt-payment-extension"
    public let extensionDescription: String = "Rokt Payment Extension"

    /// Payment methods this extension supports, determined by which parameters
    /// were provided at initialization. Apple Pay / card require
    /// `applePayMerchantId`; Afterpay requires `universalLinkReturnURL` or `urlScheme`.
    public var supportedMethods: [String] {
        var methods: [String] = []
        if let merchantId, !merchantId.isEmpty {
            methods.append(PaymentMethodType.applePay.wireValue)
            methods.append(PaymentMethodType.card.wireValue)
        }
        if afterpayReturnURL != nil {
            methods.append(PaymentMethodType.afterpay.wireValue)
        }
        return methods
    }

    // MARK: - Private Properties

    private let merchantId: String?
    private let countryCode: String
    private let urlScheme: String?
    private let universalLinkReturnURL: URL?

    private var stripeApplePayManager: StripeApplePayManager?
    private(set) var stripeAfterpayManager: StripeAfterpayManager?

    static let returnHost = "rokt-payment-return"

    /// The return URL handed to Stripe for redirect-based methods, or `nil` when
    /// Afterpay is not configured. A universal link is used verbatim; a bare
    /// scheme is composed as `<scheme>://rokt-payment-return`.
    private var afterpayReturnURL: String? {
        if let universalLinkReturnURL {
            return universalLinkReturnURL.absoluteString
        }
        if let urlScheme, !urlScheme.isEmpty {
            return "\(urlScheme)://\(Self.returnHost)"
        }
        return nil
    }

    // MARK: - Initialization

    /// Initialize the Rokt payment extension.
    ///
    /// Supply `applePayMerchantId` to enable Apple Pay / card support.
    /// Supply `universalLinkReturnURL` or `urlScheme` (not both) to enable Afterpay
    /// (redirect-based). At least one method must be enabled — otherwise the
    /// initializer returns `nil`.
    ///
    /// `universalLinkReturnURL` is the recommended Afterpay option: a plain `https` URL
    /// (host required; no query, fragment, or credentials) under a domain listed in the
    /// host app's Associated Domains entitlement (`applinks:<host>`) and covered by its
    /// `apple-app-site-association` file. The incoming URL is matched on scheme, host,
    /// and path only, so the query Stripe appends on return is ignored. Forward it from
    /// `application(_:continue:restorationHandler:)` / `scene(_:continue:)` via
    /// `userActivity.webpageURL`, or from SwiftUI `.onOpenURL`.
    ///
    /// When `urlScheme` is provided instead, the SDK builds the full redirect URL
    /// (`<scheme>://rokt-payment-return`) internally and verifies the scheme is
    /// registered under `CFBundleURLSchemes` in `Info.plist`. Custom URL schemes are
    /// not exclusive to one app, so prefer a universal link in production.
    ///
    /// - Parameters:
    ///   - applePayMerchantId: Apple Pay merchant identifier. Omit to disable Apple Pay.
    ///   - countryCode: ISO 3166-1 alpha-2 country code for the payment (default: "US").
    ///     Applies only to Apple Pay.
    ///   - urlScheme: Bare custom URL scheme (e.g. `"com.partner.app"`) for redirect-based
    ///     payment methods like Afterpay. The scheme must also be registered under
    ///     `CFBundleURLSchemes` in the host app's `Info.plist`. Omit when using
    ///     `universalLinkReturnURL`, or to disable Afterpay.
    ///   - universalLinkReturnURL: Plain https universal link (e.g.
    ///     `https://www.example.com/rokt/payment-return`) under one of the host app's
    ///     associated domains. Omit when using `urlScheme`, or to disable Afterpay.
    /// - Returns: `nil` if no method is enabled, if both `urlScheme` and
    ///   `universalLinkReturnURL` are provided, if `urlScheme` is provided but not
    ///   registered in `Info.plist`, or if `universalLinkReturnURL` is not a plain https URL.
    public convenience init?(
        applePayMerchantId: String? = nil,
        countryCode: String = "US",
        urlScheme: String? = nil,
        universalLinkReturnURL: URL? = nil
    ) {
        self.init(
            applePayMerchantId: applePayMerchantId,
            countryCode: countryCode,
            urlScheme: urlScheme,
            universalLinkReturnURL: universalLinkReturnURL,
            bundle: .main
        )
    }

    /// Internal init used by tests to inject a `Bundle` whose `Info.plist`
    /// contains a controlled `CFBundleURLTypes` entry.
    internal init?(
        applePayMerchantId: String? = nil,
        countryCode: String = "US",
        urlScheme: String? = nil,
        universalLinkReturnURL: URL? = nil,
        bundle: Bundle
    ) {
        let hasApplePay = !(applePayMerchantId?.isEmpty ?? true)
        let hasScheme = !(urlScheme?.isEmpty ?? true)
        let hasUniversalLink = universalLinkReturnURL != nil
        guard hasApplePay || hasScheme || hasUniversalLink else { return nil }

        if hasScheme, hasUniversalLink {
            Self.reportConflictingReturnConfiguration()
            return nil
        }

        if hasScheme, let scheme = urlScheme {
            guard Self.isValidBareScheme(scheme),
                  Self.isSchemeRegistered(scheme, in: bundle) else {
                Self.reportInvalidScheme(scheme)
                return nil
            }
        }

        if let universalLinkReturnURL, !ReturnURLMatching.isValidUniversalLink(universalLinkReturnURL) {
            Self.reportInvalidUniversalLink()
            return nil
        }

        self.merchantId = applePayMerchantId
        self.countryCode = countryCode
        self.urlScheme = hasScheme ? urlScheme : nil
        self.universalLinkReturnURL = universalLinkReturnURL
    }

    // MARK: - PaymentExtension Protocol Implementation

    @discardableResult
    public func onRegister(parameters: [String: String]) -> Bool {
        guard let stripeKey = parameters["stripeKey"], !stripeKey.isEmpty else {
            return false
        }

        let apiClient = STPAPIClient(publishableKey: stripeKey)

        if let merchantId, !merchantId.isEmpty {
            stripeApplePayManager = StripeApplePayManager(
                apiClient: apiClient,
                merchantId: merchantId,
                countryCode: countryCode
            )
        }

        if let returnURL = afterpayReturnURL {
            stripeAfterpayManager = StripeAfterpayManager(
                apiClient: apiClient,
                returnURL: returnURL
            )
        }

        return true
    }

    public func onUnregister() {
        stripeApplePayManager = nil
        stripeAfterpayManager = nil
    }

    public func presentPaymentSheet(
        item: PaymentItem,
        method: PaymentMethodType,
        context: PaymentContext,
        from viewController: UIViewController,
        preparePayment: @escaping (
            _ address: ContactAddress,
            _ completion: @escaping (PaymentPreparation?, Error?) -> Void
        ) -> Void,
        completion: @escaping (PaymentSheetResult) -> Void
    ) {
        switch method {
        case .applePay, .card:
            guard let stripeApplePayManager else {
                completion(.failed(error: "Apple Pay not configured. Provide applePayMerchantId at init."))
                return
            }
            stripeApplePayManager.presentPayment(
                item: item,
                from: viewController,
                preparePayment: preparePayment,
                completion: completion
            )

        case .afterpay:
            guard let stripeAfterpayManager else {
                completion(.failed(
                    error: "Afterpay not configured. Provide a urlScheme or universalLinkReturnURL at init."
                ))
                return
            }
            stripeAfterpayManager.presentPayment(
                item: item,
                context: context,
                from: viewController,
                preparePayment: preparePayment,
                completion: completion
            )

        case .paypal:
            // PayPal is defined in RoktContracts 2.x but not yet implemented here.
            // Handled explicitly (rather than falling through `@unknown default`) so the
            // compiler flags any future enum additions instead of silently accepting them.
            completion(.failed(error: "Unsupported payment method: \(method.wireValue)"))

        @unknown default:
            completion(.failed(error: "Unsupported payment method: \(method.wireValue)"))
        }
    }

    /// Forwards a redirect URL to Stripe so it can complete in-flight redirect-based
    /// flows (e.g. Afterpay). Only URLs that match the configured return URL are
    /// forwarded — anything else returns `false`, leaving partner-owned URLs untouched.
    ///
    /// - With `universalLinkReturnURL`: scheme and host are compared case-insensitively
    ///   and the path must match (a trailing slash is ignored); the query Stripe appends
    ///   is ignored. Universal links reach the host app through
    ///   `application(_:continue:restorationHandler:)` / `scene(_:continue:)`
    ///   (`userActivity.webpageURL`) or SwiftUI `.onOpenURL`; forward them to
    ///   `Rokt.handleURLCallback(with:)` the same way as custom-scheme URLs.
    /// - With `urlScheme`: the scheme must match the configured scheme and the host
    ///   must equal `rokt-payment-return`.
    public func handleURLCallback(with url: URL) -> Bool {
        guard matchesConfiguredReturnURL(url) else {
            return false
        }
        return StripeAPI.handleURLCallback(with: url)
    }

    /// Returns `true` when `url` is the return URL this extension configured for
    /// Afterpay, applying the rules described on `handleURLCallback(with:)`. A
    /// custom-scheme URL is never accepted when only a universal link is configured,
    /// and vice versa.
    internal func matchesConfiguredReturnURL(_ url: URL) -> Bool {
        if let universalLinkReturnURL {
            return ReturnURLMatching.matchesUniversalLink(url, expected: universalLinkReturnURL)
        }
        guard let urlScheme else { return false }
        return ReturnURLMatching.matchesCustomScheme(url, scheme: urlScheme, host: Self.returnHost)
    }

    // MARK: - Scheme Validation Helpers

    /// Returns `true` when the scheme is non-empty, contains no path separator
    /// characters — guarding against partners accidentally passing a full URL
    /// (e.g. `"myapp://stripe-redirect"`) or a path fragment — and is not `http` or
    /// `https`, which belong to `universalLinkReturnURL`.
    static func isValidBareScheme(_ scheme: String) -> Bool {
        let lowercased = scheme.lowercased()
        return !scheme.isEmpty && !scheme.contains("://") && !scheme.contains("/")
            && lowercased != "http" && lowercased != "https"
    }

    /// Returns `true` when `scheme` appears (case-insensitively) under any
    /// `CFBundleURLSchemes` array inside `CFBundleURLTypes` in the bundle's
    /// `Info.plist`.
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

    /// Reports an invalid / unregistered scheme.
    /// In DEBUG builds the failure is surfaced via `assertionFailure` so the
    /// integrating engineer sees it immediately. In release builds the message
    /// is logged via `os_log` at `.error` and the initializer returns `nil`,
    /// making the failure visible through the partner's `guard let ext = ...`.
    private static func reportInvalidScheme(_ scheme: String) {
        reportConfigurationFailure("""
        Rokt: URL scheme '\(scheme)' is not registered under CFBundleURLSchemes in Info.plist, \
        or is not a bare custom scheme. Register it like this:
          <key>CFBundleURLTypes</key>
          <array>
            <dict>
              <key>CFBundleURLSchemes</key>
              <array><string>\(scheme)</string></array>
            </dict>
          </array>
        """)
    }

    /// Reports a `universalLinkReturnURL` that is not a plain https URL. The URL
    /// itself is not logged.
    private static func reportInvalidUniversalLink() {
        reportConfigurationFailure("""
        Rokt: universalLinkReturnURL must be an https URL with a host and no query, fragment, \
        or credentials (e.g. https://www.example.com/rokt/payment-return). The host must also be \
        listed in the app's Associated Domains entitlement as applinks:<host>.
        """)
    }

    /// Reports that both `urlScheme` and `universalLinkReturnURL` were supplied.
    private static func reportConflictingReturnConfiguration() {
        reportConfigurationFailure(
            "Rokt: pass either urlScheme or universalLinkReturnURL, not both. Prefer universalLinkReturnURL."
        )
    }

    /// DEBUG builds surface the failure via `assertionFailure`, except while running
    /// under XCTest where the `nil` return is asserted on instead; release builds
    /// log via `os_log` at `.error`.
    private static func reportConfigurationFailure(_ message: String) {
        #if DEBUG
        if NSClassFromString("XCTestCase") == nil {
            assertionFailure(message)
            return
        }
        #endif
        os_log("%{public}s", log: .default, type: .error, message)
    }
}
