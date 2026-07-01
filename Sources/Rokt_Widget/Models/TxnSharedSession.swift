import Foundation

// Internal representation of a v2 session handed across the native<->web boundary.
// Carries the bearer token (the only thing that authenticates the session in v2)
// plus its absolute expiry, so the receiving side can continue the SAME session
// instead of minting a new one. The session id is not carried separately — it
// lives inside the token's JWT `sub` claim. Distinct from the public
// `RoktSharedSession` so the wire/credential model can evolve without breaking
// the public surface.
//
// Security note (LO-02): the synthesized `Equatable` compares `token` directly.
// This is used only by tests for round-trip assertions. Never use `==` on this
// type in security-sensitive paths (it is not constant-time) and never log,
// print, or dedup on instances of this type — `token` is a bearer credential.
internal struct TxnSharedSession: Equatable {
    let token: String
    let expiresAtDate: Date
}
