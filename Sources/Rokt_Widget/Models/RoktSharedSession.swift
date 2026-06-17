import Foundation

/// A Rokt session that can be shared across integrations so the session stays
/// consistent between, for example, a WebView-hosted web integration and the
/// native iOS SDK.
///
/// Carries the session token (the credential the SDK uses to authenticate the
/// session on the v2 Transactions Gateway) alongside its id and absolute
/// expiry. Pass an instance obtained from one integration into the other so
/// both continue the *same* session rather than each starting its own.
///
/// - Important: `token` is a bearer credential. Only move it across a boundary
///   you trust (e.g. a WebView you own). Do not log it or persist it outside
///   the SDK.
@objc public class RoktSharedSession: NSObject {
    /// The session id. Identifies the session for correlation; it does not by
    /// itself authenticate the session.
    @objc public let sessionId: String

    /// The session token, sent as `Authorization: Bearer <token>`. This is what
    /// lets the receiving integration continue the same session.
    @objc public let token: String

    /// Absolute expiry of the token. After this the session must be re-established.
    @objc public let expiresAt: Date

    @objc public init(sessionId: String, token: String, expiresAt: Date) {
        self.sessionId = sessionId
        self.token = token
        self.expiresAt = expiresAt
        super.init()
    }
}
