import Foundation

/// A Rokt session that can be shared across integrations so the session stays
/// consistent between, for example, a WebView-hosted web integration and the
/// native iOS SDK.
///
/// Carries the session token (the credential the SDK uses to authenticate the
/// session on the v2 Transactions Gateway) alongside its absolute expiry. The
/// session id is *not* carried separately: it already lives inside the token's
/// JWT `sub` claim, which is the single source of truth for session identity.
/// Pass an instance obtained from one integration into the other so both
/// continue the *same* session rather than each starting its own.
///
/// - Important: `token` is a bearer credential. Only move it across a boundary
///   you trust (e.g. a WebView you own). Do not log it or persist it outside
///   the SDK.
@objc public class RoktSharedSession: NSObject {
    /// The session token, sent as `Authorization: Bearer <token>`. This is what
    /// lets the receiving integration continue the same session. Its JWT `sub`
    /// claim carries the session id, so no separate id is needed.
    @objc public let token: String

    /// Absolute expiry of the token. After this the session must be re-established.
    @objc public let expiresAt: Date

    /// Creates a shared session bundle.
    ///
    /// - Parameters:
    ///   - token: The bearer session token. Must be non-empty; it is the
    ///     credential that continues the session and must never be logged.
    ///   - expiresAt: Absolute expiry of the token.
    /// - Important: `token` must be non-empty and `expiresAt` should be in the
    ///   future. The initializer does not reject invalid input (it stays a
    ///   non-failable `@objc` init for a simple public surface), but the SDK
    ///   silently ignores bundles with a blank credential or a past expiry when
    ///   importing them via `setSharedSession`.
    @objc public init(token: String, expiresAt: Date) {
        self.token = token
        self.expiresAt = expiresAt
        super.init()
    }
}
