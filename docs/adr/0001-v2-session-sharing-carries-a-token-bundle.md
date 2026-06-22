# v2 session sharing carries a Shared Session (token bundle), not a bare session id

## Status

accepted

## Context

The legacy SDK shares a session across a native ⇄ WebView boundary via `Rokt.setSessionId(String)` / `getSessionId() -> String?`: a bare session id, injected onto requests as the `rokt-session-id` header. An earlier (2026-06-11) plan proposed porting this to v2 unchanged — keep the `String` signatures and rely on server-side RUID Session Unification to stitch a client-supplied id.

Verified 2026-06-16 against both backends, this id-only approach is **not viable**:

- **Transactions Gateway** (`apps/api/internal/sessioninit/`): `POST /v2/sessions/init` accepts only `operating_system`, `sdk_version`, `layout_schema_version` — there is **no `session_id` field**. Session continuity is determined solely by the JWT `sub` claim in the `Authorization: Bearer <token>` header; an absent/invalid token mints a fresh `UUIDv7`. No id-based adoption exists on this endpoint.
- **WSDK** (`rokt-wsdk`): likewise authenticates subsequent calls by bearer token and keys stored tokens by id. A bare id continues nothing.

In v2, the **Session Token (JWT) is the load-bearing credential** for continuity; the id is only for correlation and the WSDK's token-keying, and it already travels inside the token's `sub` claim.

## Decision

1. **Share a token-only bundle, not an id.** v2 session sharing carries a **Shared Session** = `{ token, expiresAt }` via new public methods `setSharedSession(RoktSharedSession)` / `getSharedSession() -> RoktSharedSession?`. The bundle deliberately does **not** carry a separate `sessionId`: the session id already lives inside the token's JWT `sub` claim, which is the single source of truth for session identity. Passing a separate caller-supplied id alongside the token would be redundant and unverifiable (iOS treats the token as opaque and cannot cross-check that a supplied id matches the token's `sub`). A bare `String` cannot carry the credential, so the legacy signatures are not reused. The `expiresAt` lets the receiver check validity without decoding the token.

2. **The legacy id-only API is removed, not deprecated.** `Rokt.setSessionId(sessionId:)` / `Rokt.getSessionId()` are deleted in this change. `/experiences` is being dropped in v2 and `/offers` cannot continue a session from a client-supplied id (it authenticates by bearer token only), so the v1 id surface continues nothing and is dead weight. This is an accepted breaking change to pre-existing public API.

3. **Import is a pre-init seed consumed by `/v2/sessions/init`, not an alternative to it.** iOS always calls init regardless of any shared session (init also returns fonts, feature flags, and timeout). `setSharedSession` seeds the token into the `TxnSessionManager` that init will use, _before_ init runs; the gateway then continues that session and its init response populates the SDK's internal session id. An expired seed contributes no bearer (`authorizationHeader` is nil), so init mints a fresh session — i.e. an expired shared session is silently ignored. Export (`getSharedSession`) is a non-mutating read of the live manager (falling back to a still-valid pending seed before init runs). The ordering hazard is removed because the seed is consumed at init regardless of when it was set; concurrent access to the pending-seed/manager handshake is additionally serialized by a dedicated lock so a set on one thread cannot race init's capture-and-consume on another.

4. **`setSharedSession` may also be called after init (Thomson ②).** This is an expected, supported use case: a post-init call overrides the session established by init by seeding the new token directly into the live manager, and the new token is then used on the offers API. The same blank-token and expiry guards apply.

## Consequences

- One session-sharing surface remains on the public API (the v2 token bundle); the legacy id-only surface is gone.
- The host app remains responsible for moving the Shared Session across the native↔WebView boundary (no built-in bridge, unchanged from legacy).
- The WSDK currently has **no** token import/export API (only a web↔web cookie/localStorage recogniser bridge) — matching web-side work is required for end-to-end interop and is tracked separately. **TODO (Thomson ③):** update this ADR when the WSDK token-bridge work is delivered, to capture the agreed wire format and hand-off contract.
- id-only sharing would only become viable if the gateway added a `session_id` to the init contract plus server-side adoption; out of scope here and no longer exposed publicly.
