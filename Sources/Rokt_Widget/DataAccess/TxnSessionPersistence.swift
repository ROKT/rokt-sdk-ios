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
    static func seed(
        roktTagId: String,
        sessionId: String,
        sessionToken: TxnSessionToken,
        store: TxnSessionStore = UserDefaultsTxnSessionStore()
    ) {
        store.setString(roktTagId, forKey: TxnSessionStoreKeys.tagId)
        store.setString(sessionId, forKey: TxnSessionStoreKeys.sessionId)
        store.setString(sessionToken.token, forKey: TxnSessionStoreKeys.token)
        // Persist epoch ms as an integer string so public getSession round-trips without float drift.
        store.setString(String(sessionToken.expiresAt), forKey: TxnSessionStoreKeys.expiresAt)
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
            store.setString(String(expiresAt.timeIntervalSince1970 * 1000), forKey: TxnSessionStoreKeys.expiresAt)
        }
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

    static func readRaw(store: TxnSessionStore) -> TxnSessionSnapshot {
        let sessionId = store.string(forKey: TxnSessionStoreKeys.sessionId)
        let token = store.string(forKey: TxnSessionStoreKeys.token)
        let expiresAt = store.string(forKey: TxnSessionStoreKeys.expiresAt)
            .flatMap(Double.init)
            .map { Date(timeIntervalSince1970: $0/1000) }
        return TxnSessionSnapshot(sessionId: sessionId, token: token, expiresAt: expiresAt)
    }
}
