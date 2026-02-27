import Foundation
import UIKit
internal import RoktUXHelper

/// Rokt class to initialize and siplay Rokt's widget
@objc public class Rokt: NSObject {
    static let shared = Rokt()
    var roktImplementation = RoktInternalImplementation()

    // MARK: - Rokt internal usage functions

    @objc public static func setFrameworkType(frameworkType: RoktFrameworkType) {
        shared.roktImplementation.setFrameworkType(frameworkType)
    }

    /// Rokt internal developer facing initializer when integrating via the MParticle kit
    ///
    /// - Parameters:
    ///   - roktTagId: The tag id provided by Rokt, associated with your account.
    ///   - mParticleSdkVersion: The version of the mParticle SDK used to load Rokt mParticle kit
    ///   - mParticleKitVersion: The version of the mParticle kit used to load Rokt
    @objc public static func initWith(
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
    @objc public static func initWith(roktTagId: String) {
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
    @objc public static func selectPlacements(
        identifier: String,
        attributes: [String: String],
        placements: [String: RoktEmbeddedView]? = nil,
        config: RoktConfig? = nil,
        placementOptions: PlacementOptions? = nil,
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
    @objc public static func selectPlacements(
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
    @objc public static func close() {
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
    @objc public static func setLogLevel(_ logLevel: RoktLogLevel) {
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
    @objc public static func events(identifier: String, onEvent: ((RoktEvent) -> Void)?) {
        shared.roktImplementation.mapEvents(viewName: identifier, onEvent: onEvent)
    }

    /// Receive a stream of events generated by the Rokt SDK from all sources
    /// Additional events that are not associated with a view (such as InitComplete) will also be delivered
    ///
    /// - Parameters:
    ///   - onEvent: Function to execute when some events triggered, the first item is RoktEvent
    @objc public static func globalEvents(onEvent: @escaping ((RoktEvent) -> Void)) {
        shared.roktImplementation.mapEvents(isGlobal: true, onEvent: onEvent)
    }

    @objc public static func setEnvironment(environment: RoktEnvironment) {
        config = Configuration(environment: Configuration.getEnvironment(environment))
    }

    /// Currently by design the active Thank You page should always be the most recent Rokt layout.
    /// thus when closing the loop with purchaseFinalized, we can find the first state where instant purchase has been initiated and not closed.
    ///
    /// - Parameters:
    ///   - identifier: The identifier for the view / page where you're displaying the placement
    ///   - catalogItemId: It ID of the item being purchased
    ///   - success: Whether the purchase suceeded
    @objc public static func purchaseFinalized(identifier: String, catalogItemId: String, success: Bool) {
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
    @objc public static func setSessionId(sessionId: String) {
        shared.roktImplementation.setSessionId(sessionId: sessionId)
    }

    /// Get the session id to use within a non-native integration e.g. WebView
    ///
    /// - Returns: The session id or nil if no session is present.
    @objc public static func getSessionId() -> String? {
        shared.roktImplementation.getSessionId()
    }
}
