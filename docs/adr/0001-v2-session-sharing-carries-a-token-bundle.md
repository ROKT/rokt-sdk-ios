# v2 session sharing carries a Shared Session (token bundle), not a bare session id

## Status

accepted

## Context

The legacy SDK shares a session across a native ⇄ WebView boundary via `Rokt.setSessionId(String)` / `getSessionId() -> String?`: a bare session id, injected onto requests as the `rokt-session-id` header. An earlier (2026-06-11) plan proposed porting this to v2 unchanged — keep the `String` signatures and rely on server-side RUID Session Unification to stitch a client-supplied id.

Verified 2026-06-16 against both backends, this id-only approach is **not viable**:

- **Transactions Gateway** (`apps/api/internal/sessioninit/`): `POST /v2/sessions/init` accepts only `operating_system`, `sdk_version`, `layout_schema_version` — there is **no `session_id` field**. Session continuity is determined solely by the JWT `sub` claim in the `Authorization: Bearer <token>` header; an absent/invalid token mints a fresh `UUIDv7`. No id-based adoption exists on this endpoint.
- **WSDK** (`rokt-wsdk`): likewise authenticates subsequent calls by bearer token and keys stored tokens by id. A bare id continues nothing.

In v2, the **Session Token (JWT) is the load-bearing credential** for continuity; the id is only for correlation and the WSDK's token-keying.

## Decision

1. **Share a token bundle, not an id.** v2 session sharing carries a **Shared Session** = `{ sessionId, token, expiresAt }` via new public methods `setSharedSession(RoktSharedSession)` / `getSharedSession() -> RoktSharedSession?`, added _alongside_ the legacy `setSessionId`/`getSessionId` (which remain as the v1 id-only surface). A bare `String` cannot carry the credential, so the existing signatures are not reused. The `expiresAt` lets the receiver check validity without decoding the token, which iOS treats as opaque.

2. **Import is a pre-init seed consumed by `/v2/sessions/init`, not an alternative to it.** iOS always calls init regardless of any shared session (init also returns fonts, feature flags, and timeout). `setSharedSession` seeds the token into the `TxnSessionManager` that init will use, _before_ init runs; the gateway then continues that session. An expired seed contributes no bearer (`authorizationHeader` is nil), so init mints a fresh session — i.e. an expired shared session is silently ignored. Export (`getSharedSession`) is a non-mutating read of the live manager (falling back to a still-valid pending seed before init runs). The ordering hazard is removed because the seed is consumed at init regardless of when it was set; concurrent access to the pending-seed/manager handshake is additionally serialized by a dedicated lock so a set on one thread cannot race init's capture-and-consume on another.

## Consequences

- Two session-sharing surfaces coexist on the public API (legacy id-only + v2 Shared Session); doc-comments must steer v2 integrators to `setSharedSession`.
- The host app remains responsible for moving the Shared Session across the native↔WebView boundary (no built-in bridge, unchanged from legacy).
- The WSDK currently has **no** token import/export API (only a web↔web cookie/localStorage recogniser bridge) — matching web-side work is required for end-to-end interop and is tracked separately.
- id-only sharing would only become viable if the gateway added a `session_id` to the init contract plus server-side adoption; out of scope here.
