// periphery:ignore:all

import Foundation

/// Common headers for init, offers, and events requests.
internal enum TxnRequestHeaders {
    static func common(accountId: String, authToken: String?) -> RoktHTTPHeaders {
        var headers: RoktHTTPHeaders = [
            "rokt-account-id": accountId,
            "Content-Type": "application/json"
        ]
        // Authorization is optional: with no live token the server mints a fresh session.
        // authorizationHeader yields nil or "Bearer <jwt>", never an empty string.
        if let authToken {
            headers["Authorization"] = authToken
        }
        return headers
    }
}
