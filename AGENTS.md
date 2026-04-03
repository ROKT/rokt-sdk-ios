# AGENTS.md

## Role for agents

You are a senior iOS SDK engineer specializing in stable, lightweight client libraries for e-commerce / ad-tech integrations.

- Treat this as a **public SDK / framework**, not a full consumer app.
- Prioritize: API stability, minimal footprint, no unnecessary allocations, thread-safety, backward compatibility (iOS 15+), privacy compliance.
- Never assume this is a UIKit/SwiftUI app with heavy views/controllers — focus on modular widget/placement rendering logic.
- Avoid proposing big refactors unless explicitly asked; prefer additive changes + deprecations.

## Quick Start for Agents

- Open `Example/rokt.xcodeproj` in the latest Xcode (supports iOS 15+ deployment target).
- Primary schemes:
  - `rokt-Example` → build/run sample app and unit tests (Command + R / Command + U).
  - `rokt-Example-STAGE` → UI/integration tests.
  - `Rokt-Widget` → build SDK framework only.
- Always validate changes with the full sequence in "Code style, quality, and validation" below before proposing or committing.

## Strict Do's and Don'ts

### Always Do

- Use value types (struct/enum) over reference types where possible.
- Mark public APIs with thorough `///` documentation (DocC compatible).
- Keep public surface additive; deprecate instead of remove.
- Explicitly dispatch UI work to main actor (`@MainActor`, `DispatchQueue.main.async`).
- Prefer async/await for new code; existing networking uses completion handlers.
- Measure & report size impact before proposing dependency or asset changes.

### Never automatically (unless specifically requested)

- Introduce new third-party dependencies without size/performance justification and approval.
- Modify or depend on host app singletons/globals unless explicitly in public API contract.
- Block the main thread (no synchronous network, heavy computation, etc.).
- Crash on bad input/network — always provide fallback / error callback.
- Touch CI YAML without explicit request.
- Propose dropping iOS 15 support or raising min deployment target.
- Introduce breaking changes unless explicitly requested. Ask when in doubt.

## When to Ask for Clarification

- Before adding any new dependency
- Before dropping support for iOS versions
- Before making breaking API changes
- When a "simple" refactor reveals deeper architectural issues
- When test failures suggest the original code may have had bugs

## Project overview

- Rokt iOS SDK written in Swift.
- Core SDK code lives in `Sources/Rokt_Widget/`.
- Primary public API entry point is `Rokt.swift`.

## Key paths

- `Sources/Rokt_Widget/`: SDK source code.
- `Package.swift`: SPM config and dependency pins.
- `Rokt-Widget.podspec`: CocoaPods spec for source distribution.
- `Sources/Rokt_Widget/PrivacyInfo.xcprivacy`: privacy manifest.
- `Tests/Rokt_WidgetTests/`: unit tests.
- `Example/`: sample app and UI/integration tests.
- `Example/Tests/`: test files and JSON fixtures.
- `Tests/SizeReport/`: SDK size report tooling (`measure_size.sh`).
- `CHANGELOG.md`: release notes.
- `VERSION`: release version used by workflows.
- `.periphery.yml`: unused code detection config.

## Code style, quality, and validation

- **Lint & format tools**:
  - SwiftFormat: configured in `.swiftformat` (run `swiftformat .` to format).
  - SwiftLint: configured in `.swiftlint.yml`.
  - **Primary enforcement tool**: `trunk check` (via Trunk.io) — assumes Trunk is installed and configured (e.g., `.trunk/trunk.yaml` wraps SwiftFormat + SwiftLint + others). If Trunk unavailable, fall back to `swiftformat .` && `swiftlint`.
  - Keep code consistent by running these before any commit/PR.
  - Important: Only add comments if absolutely necessary.
  - If you're adding comments review why the code is hard to reason with and rewrite that first

- **Strict post-change validation rule (always follow this)**:
  After **any** code change, refactor, or addition — even small ones — you **must** run the full validation sequence locally:
  1. `trunk check` — to lint, format-check, and catch style/quality issues.
  2. Build the SDK: Open `Example/rokt.xcodeproj` → build the `rokt-Example` scheme (or `xcodebuild` if scripting).
  3. Run unit tests: Use the `rokt-Example` scheme → Command + U (or `xcodebuild test ...`).
  4. Run periphery scan: `periphery scan` — ensure no unused code is introduced.
  5. If change affects code, assets, or dependencies: Run size report → `Tests/SizeReport/measure_size.sh` and confirm no unacceptable increase.
  - Only propose / commit changes if all steps pass cleanly (no errors, no warnings from `trunk check`, tests green, size OK).
  - If `trunk check` suggests auto-fixes (e.g. formatting), apply them first and re-validate.
  - Never bypass this — it's required to maintain SDK stability, footprint, and public API quality.

- **Style preferences**:
  - Prefer `let` over `var`; use value types (struct/enum) over classes where possible.
  - Use property wrappers (`@MainActor`, `@Observable`) appropriately.
  - Write thorough `///` documentation for all public APIs (DocC compatible).
  - Avoid force-unwraps (`!`), prefer safe optional handling.
  - Follow immutability principles: minimize shared mutable state wherever possible.

- **Testing expectations**:
  - Unit tests live in `Tests/Rokt_WidgetTests/` or alongside source files when appropriate.
  - Aim for high coverage on core logic: placement selection, rendering, networking, error paths.
  - Use mocks/fixtures from `Example/Tests/` (JSON files and `NetworkMock/`) for networking and dependencies.
  - Stick to XCTest — no third-party test frameworks unless already implemented or directed.
  - UI/integration tests use the `rokt-Example-STAGE` scheme and Quick/Nimble framework.
  - After changes, always re-run affected tests + full suite if core/shared code is touched.

- **CHANGELOG.md maintenance**:
  - We follow a hybrid approach: Minor/trivial changes (e.g., dependency bumps, small internal refactors, lint fixes) do **not** require manual entries — these are already obvious in the commit history.
  - For **substantial changes** (new features, API additions/deprecations, behavior changes affecting partners, bug fixes with user impact, performance improvements, security updates), **always add a clear, human-written entry** to `CHANGELOG.md` under the appropriate version section.
  - Use standard categories: `Added`, `Changed`, `Deprecated`, `Fixed`, `Removed`, `Security` (per Keep a Changelog / SemVer conventions).
  - Keep entries concise, user/partner-focused (what changed and why it matters), and written in imperative mood (e.g., "Added new placement rendering API" not "Adds...").
  - Update `CHANGELOG.md` **before** finalizing a change.
  - Never auto-generate or hallucinate changelog entries and flag for human review.

## Pull request and branching

- Ensure the branch is created with a feat/\* pattern e.g. fix, perf, ci, docs, test, etc
- Keep commits to a minimum before opening the pull request and try to follow the pattern "feat: Short description summarising changes" e.g. "feat: Increased timeout for experiences call to 8000ms" for the commit message
- When creating pull requests Use the the template, located at: .github/pull_request_template.md, as the basis for the description

## External Resources

- [Rokt Developer Docs](https://docs.rokt.com/developers/integration-guides/ios/overview)
- [UX Helper Repository](https://github.com/ROKT/rokt-ux-helper-ios)

## Review guidelines

When reviewing PRs that touch this repo or downstream services, apply these
severity levels.

### P0 — block merge

- Hardcoded secrets or credentials (API keys, tokens, passwords, DB URIs)
- SQL string interpolation or concatenation (use parameterised queries only)

### P1 — strongly recommend fixing before merge

- Real customer PII in code or tests (names, emails, phone numbers, IP addresses — including hashed)
- `aws_iam_policy_attachment` Terraform resource (use `aws_iam_role_policy_attachment`)
- AI/ML Helm services using `Service.type: LoadBalancer` without internal annotation
- Missing input validation or sanitisation at API boundaries
- HTML/template rendering without escaping all 5 special chars (`<` `>` `"` `'` `&`)
- `VARCHAR` for user-visible strings in SQL Server (use `NVARCHAR`)
- `varchar`/`utf8` charset for user-visible strings in MySQL (use `utf8mb4`)
- Redis clients without DNS TTL re-resolution
- Submit buttons with no disabled state during async operations
- UI navigation hiding used as sole access control (no backend auth check)
- K8s Deployments/Services missing `service-type: internal|edge|public` label
