import Foundation

/// UserDefaults keys shared by ``TxnSessionManager`` and the public session handoff APIs.
internal enum TxnSessionStoreKeys {
    static let tagId = "ROKT_TXN_TAG_ID"
    static let sessionId = "ROKT_TXN_SESSION_ID"
    static let token = "ROKT_TXN_SESSION_TOKEN"
    static let expiresAt = "ROKT_TXN_TOKEN_EXPIRES_AT"
    static let epoch = "ROKT_TXN_SESSION_EPOCH"
}

/// In-memory view of a persisted txn session (id + JWT + expiry).
internal struct TxnSessionSnapshot: Equatable {
    let sessionId: String?
    let token: String?
    let expiresAt: Date?
}

/// Synchronous read/write for the txn session store so public APIs can seed state
/// before the next offers/events call constructs a ``TxnSessionManager``.
internal enum TxnSessionPersistence {
    /// Longest token lifetime accepted from a server response or a partner handoff. Real tokens
    /// live for minutes; anything further out is clamped so the stored expiry always fits an `Int64`.
    static let maxTokenTTL: TimeInterval = 366 * 24 * 60 * 60

    static func seed(
        roktTagId: String,
        sessionId: String,
        sessionToken: TxnSessionToken,
        store: TxnSessionStore = UserDefaultsTxnSessionStore(),
        now: Date = Date()
    ) {
        let bounded = sessionToken.clampingExpiry(now: now)
        store.setString(roktTagId, forKey: TxnSessionStoreKeys.tagId)
        store.setString(sessionId, forKey: TxnSessionStoreKeys.sessionId)
        store.setString(bounded.token, forKey: TxnSessionStoreKeys.token)
        writeExpiry(milliseconds: bounded.expiresAt, store: store)
    }

    /// Epoch milliseconds of `date`, or `nil` when the value does not fit an `Int64`.
    static func epochMilliseconds(_ date: Date) -> Int64? {
        Int64(exactly: (date.timeIntervalSince1970 * 1000).rounded(.down))
    }

    /// Clamps an epoch-millisecond expiry to `now + maxTokenTTL`.
    static func boundedExpiryMilliseconds(_ expiresAt: Int64, now: Date) -> Int64 {
        min(expiresAt, epochMilliseconds(now.addingTimeInterval(maxTokenTTL)) ?? Int64.max)
    }

    static func isBound(to roktTagId: String, store: TxnSessionStore) -> Bool {
        store.string(forKey: TxnSessionStoreKeys.tagId) == roktTagId
    }

    static func clear(store: TxnSessionStore) {
        store.removeValue(forKey: TxnSessionStoreKeys.tagId)
        store.removeValue(forKey: TxnSessionStoreKeys.sessionId)
        store.removeValue(forKey: TxnSessionStoreKeys.token)
        store.removeValue(forKey: TxnSessionStoreKeys.expiresAt)
    }

    static func persist(
        roktTagId: String,
        sessionId: String?,
        token: String?,
        expiresAt: Date?,
        includeSessionId: Bool,
        store: TxnSessionStore
    ) {
        // Always record the tag-id binding: restore treats a missing/mismatched
        // tag id as another account's data and clears the session, so a token persisted
        // without it would never survive a reload.
        store.setString(roktTagId, forKey: TxnSessionStoreKeys.tagId)
        if includeSessionId, let sessionId {
            store.setString(sessionId, forKey: TxnSessionStoreKeys.sessionId)
        }
        if let token {
            store.setString(token, forKey: TxnSessionStoreKeys.token)
        }
        if let expiresAt {
            if let milliseconds = epochMilliseconds(expiresAt) {
                writeExpiry(milliseconds: milliseconds, store: store)
            } else {
                store.removeValue(forKey: TxnSessionStoreKeys.expiresAt)
            }
        }
    }

    // Integer epoch ms, so public getSession round-trips without float drift.
    private static func writeExpiry(milliseconds: Int64, store: TxnSessionStore) {
        store.setString(String(milliseconds), forKey: TxnSessionStoreKeys.expiresAt)
    }

    static func isExpired(expiresAt: Date?, clock: () -> Date) -> Bool {
        guard let expiresAt else { return true }
        return clock() >= expiresAt
    }

    /// Clears the store when the snapshot is expired. Returns `true` if it cleared.
    @discardableResult
    static func clearIfExpired(
        expiresAt: Date?,
        store: TxnSessionStore,
        clock: () -> Date
    ) -> Bool {
        guard isExpired(expiresAt: expiresAt, clock: clock) else {
            return false
        }
        clear(store: store)
        return true
    }

    static func readRaw(store: TxnSessionStore, now: Date = Date()) -> TxnSessionSnapshot {
        let sessionId = store.string(forKey: TxnSessionStoreKeys.sessionId)
        let token = store.string(forKey: TxnSessionStoreKeys.token)
        let expiresAt = store.string(forKey: TxnSessionStoreKeys.expiresAt)
            .flatMap(Double.init)
            .flatMap { Self.date(fromEpochMilliseconds: $0, now: now) }
        return TxnSessionSnapshot(sessionId: sessionId, token: token, expiresAt: expiresAt)
    }

    // `Double.init` accepts "inf", "nan" and exponents past Int64, and a store written before this
    // bound existed may hold a far-future value. Anything non-finite, negative or beyond
    // `now + maxTokenTTL` reads as "no expiry" (already expired), so it is cleared instead of being
    // converted back to an integer or authorizing requests for years. Both the legacy
    // Double-formatted string and the integer string are accepted.
    private static func date(fromEpochMilliseconds milliseconds: Double, now: Date) -> Date? {
        let cap = now.addingTimeInterval(maxTokenTTL).timeIntervalSince1970 * 1000
        guard milliseconds.isFinite, milliseconds >= 0, milliseconds <= cap else { return nil }
        return Date(timeIntervalSince1970: milliseconds/1000)
    }
}
