import Foundation

/// A Rokt session suitable for handoff between native and non-native integrations (e.g. WebView).
///
/// Includes the session id plus the short-lived session token used to authorize offers and events.
@objc public class RoktSession: NSObject {
    /// The Rokt session identifier.
    @objc public let sessionId: String

    /// The JWT session token used as a Bearer credential for offers and events.
    @objc public let sessionToken: String

    /// Unix epoch milliseconds when ``sessionToken`` expires (matches server `expires_at`).
    @objc public let expiresAt: Int64

    /// Creates a session handoff value.
    ///
    /// - Parameters:
    ///   - sessionId: The Rokt session identifier. Must be non-empty when passed to ``Rokt/setSession(_:)``.
    ///   - sessionToken: The JWT session token. Must be non-empty when passed to ``Rokt/setSession(_:)``.
    ///   - expiresAt: Token expiry as Unix epoch milliseconds.
    @objc public init(sessionId: String, sessionToken: String, expiresAt: Int64) {
        self.sessionId = sessionId
        self.sessionToken = sessionToken
        self.expiresAt = expiresAt
        super.init()
    }
}
