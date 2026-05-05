import Foundation
import UIKit
@_exported import RoktContracts
internal import RoktUXHelper

/// Rokt class to initialize and display Rokt's widget
@objcMembers
@objc public class Rokt: NSObject {
    static let shared = Rokt()
    var roktImplementation = RoktInternalImplementation()

    // MARK: - Rokt internal usage functions

    public static func setFrameworkType(frameworkType: RoktFrameworkType) {
        shared.roktImplementation.setFrameworkType(frameworkType)
    }

    /// Rokt internal developer facing initializer when integrating via the MParticle kit
    ///
    /// - Parameters:
    ///   - roktTagId: The tag id provided by Rokt, associated with your account.
    ///   - mParticleSdkVersion: The version of the mParticle SDK used to load Rokt mParticle kit
    ///   - mParticleKitVersion: The version of the mParticle kit used to load Rokt
    public static func initWith(
        roktTagId: String,
        mParticleSdkVersion: String,
        mParticleKitVersion: String
    ) {
        let mParticleKitDetails = MParticleKitDetails(
            sdkVersion: mParticleSdkVersion,
            kitVersion: mParticleKitVersion
        )

        shared.roktImplementation.initWith(
            roktTagId: roktTagId,
            mParticleKitDetails: mParticleKitDetails
        )
    }

    // MARK: - Rokt public functions

    /// Function to initialize the Rokt SDK
    ///
    /// - Parameters:
    ///   - roktTagId: The tag ID provided by your dedicated Rokt team
    public static func initWith(roktTagId: String) {
        RoktLogger.shared.info("Initializing Rokt SDK")
        shared.roktImplementation.initWith(roktTagId: roktTagId, mParticleKitDetails: nil)
    }

    /// Select the most relevant placements for your users
    ///
    /// - Parameters:
    ///   - identifier: The identifier for the view / page where you're displaying the placement
    ///   - attributes: A string dictionary containing the attributes to select the best placements
    ///   - placements: A dictionary of RoktEmbeddedViews with their names
    ///   - config: An object which defines RoktConfig
    ///   - placementOptions: (Internal use only) Placement options containing timing data from joint SDKs
    ///   - onEvent: Function to execute when some events triggered, the first item is RoktEvent
    public static func selectPlacements(
        identifier: String,
        attributes: [String: String],
        placements: [String: RoktEmbeddedView]? = nil,
        config: RoktConfig? = nil,
        placementOptions: RoktPlacementOptions? = nil,
        onEvent: ((RoktEvent) -> Void)? = nil
    ) {
        shared.roktImplementation.execute(
            viewName: identifier,
            attributes: attributes,
            placements: placements,
            config: config,
            placementOptions: placementOptions,
            onRoktEvent: { roktEvent in
                onEvent?(roktEvent)
            }
        )
    }

    /// Select the most relevant placements for your users
    ///
    /// - Parameters:
    ///   - identifier: The identifier for the view / page where you're displaying the placement
    ///   - attributes: A string dictionary containing the attributes to select the best placements
    ///   - placements: A dictionary of RoktEmbeddedViews with their names
    ///   - onEvent: Function to execute when some events triggered, the first item is RoktEvent
    public static func selectPlacements(
        identifier: String,
        attributes: [String: String],
        placements: [String: RoktEmbeddedView]? = nil,
        onEvent: ((RoktEvent) -> Void)? = nil
    ) {
        selectPlacements(
            identifier: identifier,
            attributes: attributes,
            placements: placements,
            config: nil,
            placementOptions: nil,
            onEvent: onEvent,
        )
    }

    /// Close any active placements of the following styles: overlay, lightbox, bottomsheet
    public static func close() {
        shared.roktImplementation.close()
    }

    /// Sets the log level for Rokt SDK console output.
    ///
    /// This explicitly propagates the log level to the underlying UX Helper,
    /// ensuring consistent logging behavior across all Rokt components.
    ///
    /// - Parameter logLevel: The minimum log level to display. Default is `.none`.
    ///
    /// Example:
    /// ```swift
    /// Rokt.setLogLevel(.debug)
    /// ```
    public static func setLogLevel(_ logLevel: RoktLogLevel) {
        RoktLogger.shared.logLevel = logLevel
        if #available(iOS 15.0, *) {
            RoktUX.setLogLevel(logLevel.toUXLogLevel())
        }
    }

    /// Rokt developer facing events subscription
    ///
    /// - Parameters:
    ///   - identifier: The identifier for the view / page where you're displaying the placement
    ///   - onEvent: Function to execute when some events triggered, the first item is RoktEvent
    public static func events(identifier: String, onEvent: ((RoktEvent) -> Void)?) {
        shared.roktImplementation.mapEvents(viewName: identifier, onEvent: onEvent)
    }

    /// Receive a stream of events generated by the Rokt SDK from all sources
    /// Additional events that are not associated with a view (such as InitComplete) will also be delivered
    ///
    /// - Parameters:
    ///   - onEvent: Function to execute when some events triggered, the first item is RoktEvent
    public static func globalEvents(onEvent: @escaping ((RoktEvent) -> Void)) {
        shared.roktImplementation.mapEvents(isGlobal: true, onEvent: onEvent)
    }

    public static func setEnvironment(environment: RoktEnvironment) {
        config = Configuration(environment: Configuration.getEnvironment(environment))
    }

    /// Routes all Rokt SDK requests through a custom CNAME domain.
    /// Must be called before `initWith(roktTagId:)`.
    /// Non-HTTPS URLs or URLs with a missing/empty host are rejected with a warning.
    /// Any path, query, or fragment on the URL is ignored — only the scheme, host, and port are used.
    public static func setCustomBaseURL(_ url: URL) {
        guard url.scheme?.lowercased() == "https", let host = url.host, !host.isEmpty else {
            RoktLogger.shared.warning("Rokt: custom base URL must use HTTPS and include a valid host - ignored.")
            return
        }
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.port = url.port
        config = Configuration(environment: .custom(baseURL: components.string ?? url.absoluteString))
    }

    /// Register a payment extension for Shoppable Ads.
    ///
    /// The partner passes configuration (e.g. Stripe publishable key) at runtime.
    /// Must be called before `selectShoppableAds()`.
    ///
    /// - Parameters:
    ///   - paymentExtension: The payment extension to register (e.g. `RoktPaymentExtension`)
    ///   - config: Configuration dictionary (e.g. `["stripeKey": "pk_live_..."]`)
    public static func registerPaymentExtension(
        _ paymentExtension: PaymentExtension,
        config: [String: String] = [:]
    ) {
        shared.roktImplementation.registerPaymentExtension(paymentExtension, config: config)
    }

    /// Sets the host app’s **bare** custom URL scheme (e.g. `"myapp"`, no `://`) used for **built-in PayPal** device-pay redirects.
    ///
    /// **Required** before PayPal device pay from a placement: the SDK always composes return/cancel as
    /// `\(scheme)://rokt-paypal-return` and `\(scheme)://rokt-paypal-cancel` (same idea as the Stripe payment extension’s fixed host pattern).
    /// Register **scheme** under `CFBundleURLTypes` / `CFBundleURLSchemes` in `Info.plist`, then forward matching URLs to ``handleURLCallback(with:)``.
    ///
    /// Pass `nil` to clear the stored scheme (PayPal device pay will fail until you set a valid scheme again).
    ///
    /// - Parameter scheme: Bare scheme string, or `nil` to clear.
    /// - Returns: `false` if a non-empty scheme is malformed or not declared in `Info.plist` when that check applies (skipped under XCTest and in **DEBUG** for known Rokt sample apps; see ``PayPalRedirectURLSchemeValidator/shouldValidateAgainstInfoPlist``).
    @discardableResult
    public static func setBuiltInPayPalRedirectURLScheme(_ scheme: String?) -> Bool {
        shared.roktImplementation.setBuiltInPayPalRedirectURLScheme(scheme)
    }

    /// Forward an incoming URL to built-in PayPal (when active) and registered payment extensions.
    ///
    /// Redirect-based payment methods (e.g. Afterpay, built-in PayPal) authenticate in a browser or
    /// web view and return to the host app via a custom URL scheme. The host app should forward every
    /// incoming URL to this method — the SDK handles built-in PayPal first, then asks each registered
    /// extension until one recognizes the URL.
    ///
    /// Example (SwiftUI):
    /// ```swift
    /// WindowGroup {
    ///     ContentView()
    ///         .onOpenURL { url in
    ///             Rokt.handleURLCallback(with: url)
    ///         }
    /// }
    /// ```
    ///
    /// - Parameter url: The URL received by the host app.
    /// - Returns: `true` if built-in PayPal or a registered payment extension handled the URL.
    @discardableResult
    public static func handleURLCallback(with url: URL) -> Bool {
        shared.roktImplementation.handleURLCallback(with: url)
    }

    /// Display a Shoppable Ads overlay placement.
    ///
    /// Always renders as an overlay/lightbox — no embedded views.
    /// Shows a loading indicator immediately while fetching the experience.
    /// Requires `registerPaymentExtension()` to be called first.
    ///
    /// - Parameters:
    ///   - identifier: The identifier for the view / page where you're displaying the placement
    ///   - attributes: User attributes for targeting
    ///   - config: Optional configuration (color mode, caching)
    ///   - onEvent: Callback for placement lifecycle and purchase events
    public static func selectShoppableAds(
        identifier: String,
        attributes: [String: String],
        config: RoktConfig? = nil,
        onEvent: ((RoktEvent) -> Void)? = nil
    ) {
        shared.roktImplementation.selectShoppableAds(
            identifier: identifier,
            attributes: attributes,
            config: config,
            onRoktEvent: onEvent
        )
    }

    /// Currently by design the active Thank You page should always be the most recent Rokt layout.
    /// thus when closing the loop with purchaseFinalized, we can find the first state where instant purchase has been initiated and not closed.
    ///
    /// - Parameters:
    ///   - identifier: The identifier for the view / page where you're displaying the placement
    ///   - catalogItemId: It ID of the item being purchased
    ///   - success: Whether the purchase suceeded
    public static func purchaseFinalized(identifier: String, catalogItemId: String, success: Bool) {
        shared.roktImplementation.purchaseFinalized(identifier: identifier, catalogItemId: catalogItemId, success: success)
    }

    /// Set the session id to use for the next execute call.
    /// This is useful for cases where you have a session id from a non-native integration,
    /// e.g. WebView, and you want the session to be consistent across integrations.
    ///
    /// - Note: Empty strings are ignored and will not update the session.
    ///
    /// - Parameters:
    ///   - sessionId: The session id to be set. Must be a non-empty string.
    public static func setSessionId(sessionId: String) {
        shared.roktImplementation.setSessionId(sessionId: sessionId)
    }

    /// Get the session id to use within a non-native integration e.g. WebView
    ///
    /// - Returns: The session id or nil if no session is present.
    public static func getSessionId() -> String? {
        shared.roktImplementation.getSessionId()
    }
}
