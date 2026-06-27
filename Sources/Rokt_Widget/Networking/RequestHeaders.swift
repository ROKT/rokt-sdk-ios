// periphery:ignore:all - shared v2 transactions request headers

import Foundation

/// Single owner for the headers common to every v2 transactions request
/// (init / events / offers): the account id, content type, the live/non-shadow
/// flag, and the optional Authorization. Centralised so the shadow and auth
/// rules can't drift between the three clients (a partial edit would otherwise
/// send one endpoint live and another shadow for the same session).
internal enum RequestHeaders {
    static let shadowHeaderKey = "rokt-txn-shadow"

    static func common(accountId: String, authToken: String?) -> RoktHTTPHeaders {
        var headers: RoktHTTPHeaders = [
            "rokt-account-id": accountId,
            // Live (non-shadow) v2 request.
            shadowHeaderKey: "false",
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
