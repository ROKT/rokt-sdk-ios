import Foundation

/// A Rokt session suitable for handoff between native and non-native integrations (e.g. WebView).
///
/// Includes the session id plus the short-lived session token used to authorize offers and events.
/// ``expiresAt`` is optional so partners can mirror Web launcher options (`sessionId` + `sessionToken`)
/// without supplying a client-side expiry.
@objc public class RoktSession: NSObject {
    /// The Rokt session identifier.
    @objc public let sessionId: String

    /// The JWT session token used as a Bearer credential for offers and events.
    @objc public let sessionToken: String

    /// Unix epoch milliseconds when ``sessionToken`` expires (matches server `expires_at` when known).
    ///
    /// Optional for partner handoff. When omitted (or already past) on ``Rokt/setSession(_:)``,
    /// the SDK applies a short-lived default TTL for local persistence.
    @objc public let expiresAt: NSNumber?

    /// Creates a session handoff value.
    ///
    /// - Parameters:
    ///   - sessionId: The Rokt session identifier. Must be non-empty when passed to ``Rokt/setSession(_:)``.
    ///   - sessionToken: The JWT session token. Must be non-empty when passed to ``Rokt/setSession(_:)``.
    ///   - expiresAt: Optional token expiry as Unix epoch milliseconds (`nil` if unknown).
    @objc public init(sessionId: String, sessionToken: String, expiresAt: NSNumber? = nil) {
        self.sessionId = sessionId
        self.sessionToken = sessionToken
        self.expiresAt = expiresAt
        super.init()
    }
}

public extension RoktSession {
    /// Swift-friendly initializer using `Int64` milliseconds.
    convenience init(sessionId: String, sessionToken: String, expiresAtMilliseconds: Int64?) {
        self.init(
            sessionId: sessionId,
            sessionToken: sessionToken,
            expiresAt: expiresAtMilliseconds.map { NSNumber(value: $0) }
        )
    }
}
