// periphery:ignore:all - shared v2 transactions request headers

import Foundation

/// Single owner for the headers common to every v2 transactions request
/// (init / events / offers): the account id, content type, and the optional
/// Authorization. Centralised so the auth rule can't drift between the three clients.
internal enum RequestHeaders {
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
