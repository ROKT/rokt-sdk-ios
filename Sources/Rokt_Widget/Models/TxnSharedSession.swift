import Foundation

// Internal representation of a v2 session handed across the native<->web boundary.
// Carries the bearer token (the only thing that authenticates the session in v2)
// plus its id and absolute expiry, so the receiving side can continue the SAME
// session instead of minting a new one. Distinct from the public `RoktSharedSession`
// so the wire/credential model can evolve without breaking the public surface.
internal struct TxnSharedSession: Equatable {
    let sessionId: String
    let token: String
    let expiresAtDate: Date
}
