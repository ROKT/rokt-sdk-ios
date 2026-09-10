# rokt-sdk-ios - Agent Instructions

This file is loaded into every agent session, so it holds only what you cannot get from the
repository itself. Anything a config already states — deployment target, dependency versions,
lint rules, scheme names — is deliberately absent: read `Package.swift`, `Rokt-Widget.podspec`,
`.swiftlint.yml`, `.swiftformat`, `.periphery.yml`, `.trunk/trunk.yaml` and
`.github/workflows/`. Release, subtree and mirror mechanics live in `MONOREPO.md`; partner
integration docs are at <https://docs.rokt.com/developers/integration-guides/ios/overview>.

## What this is

A public, source-distributed iOS SDK consumed by partner apps over SPM and CocoaPods — not an
app. Priorities, in order: public API stability, binary size, thread safety, privacy. Prefer
additive change and deprecation over refactoring. Never crash or block the main thread on bad
input or a failed request; fall back and report through the error callback.

## This is a PUBLIC repository

Everything written here is world-readable and permanent: PR titles and bodies, commit messages,
branch names, code comments, CHANGELOG entries, test names. Never include partner, client or
advertiser names, or any detail that could identify one (account, tenant or campaign IDs, deal
terms, integration specifics); internal service, contract or class names and their field
layouts; backend or infrastructure detail, especially anything describing how a payload is
validated server-side, which reads as a probing aid; or links to private repos, internal
tickets or dashboards. Describe client-side behaviour only — what the SDK sends and receives
and why, in partner-facing terms — and refer to a server change generically ("to match the
server contract"). Internal rationale belongs in internal review or a private ticket, not in
repo history.

## Repository layout

Only the parts `ls` will not tell you:

- `Sources/Rokt_Widget/Rokt.swift` — the public API entry point.
- `Packages/rokt-payment-extension-ios/` — a git subtree mirrored out to its own repo on release,
  not a vendored third party. It shares the root `VERSION`. `MONOREPO.md` has the mechanics, and
  documents `Packages/matrix.json`, which drives the mirror and CocoaPods ordering.
- `Example/Tests/` — the `rokt_Tests` target: Quick/Nimble specs, the JSON layout fixtures and
  `NetworkMock/`. This is what CI labels "UI Tests".
- `Tests/Rokt_WidgetTests/` — SPM unit tests. `Tests/ContractTests/` — the PactSwift consumer
  contract.
- `Tests/SizeReport/` — two apps that `measure_size.sh` builds and diffs. The with-SDK one
  references this package by relative path, so it measures your working tree, not a release.

## Commands

| Task                          | Command                                                                                                       |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Lint and format as CI does    | `trunk check --all`; `trunk fmt` to apply                                                                     |
| Unit tests only               | `xcodebuild test -scheme Rokt-Widget -only-testing:Rokt_WidgetTests -destination '<simulator>'`               |
| The specs CI calls "UI Tests" | `xcodebuild test -project Example/rokt.xcodeproj -scheme rokt-Example-MOCK -destination '…'`                  |
| Consumer contract only        | `xcodebuild test -scheme Rokt-Widget -only-testing:ContractTests`, `TEST_RUNNER_PACT_OUTPUT_DIR` set — trap 2 |
| Unused-code scan              | index-store build first, then `periphery scan` — see trap 4                                                   |
| SDK size delta                | `Tests/SizeReport/measure_size.sh` (`--json` for the CI shape)                                                |

### Command traps

1. `trunk check` with no arguments checks **only files changed against the upstream branch**,
   while CI runs the Trunk action with `check-mode: all`. A pre-existing violation in a file you
   never touched is green locally and red in CI. Run `trunk check --all` before pushing.
2. `xcodebuild test -scheme Rokt-Widget` runs **both** SPM test targets, `ContractTests`
   included. The specs read `PACT_OUTPUT_DIR`, but a plain export of it never reaches a test
   process running in the Simulator: export `TEST_RUNNER_PACT_OUTPUT_DIR` and `xcodebuild` strips
   the prefix on arrival, which is what the Consumer Test workflow does. Get that wrong and the
   specs still **pass**, writing to their fallback `pacts/` inside the simulator container rather
   than the host path you asked for — and `pacts/` is gitignored, so there is nothing to notice.
   Pass `-only-testing:Rokt_WidgetTests` when you only want unit tests.
3. There is no XCUITest in this repo. `Example/rokt.xcodeproj` defines only the `rokt_Example`
   app and the `rokt_Tests` bundle; the "UI Tests" job runs the Quick/Nimble specs in
   `Example/Tests/` through the `rokt-Example-MOCK` scheme — use that one. `rokt-Example` and
   `rokt-Example-STAGE` still list a `rokt_ExampleUITests` testable that no longer exists as a
   target, skipped in the former and not skipped in the latter.
4. Bare `periphery scan` cannot work here. `.periphery.yml` sets `skip_build: true` and reads a
   pre-built index store out of `DerivedData-periphery/`, so run the workflow's indexing build
   first — same `-derivedDataPath`, with the two index-store build settings the Periphery Scan
   job passes. It is also `strict: true` with a baseline file: pre-existing findings are
   suppressed, new ones fail. Fix the finding rather than widening the baseline.
5. **The size report cannot fail a PR, and its `N/A`s do not mean what they look like.** Both
   measurement steps are `continue-on-error: true` and send the script's stderr to `/dev/null`,
   so a failed measurement is a green step with no log. The comment's formatter renders a `0` as
   `N/A`, so a change with no size impact reports `Change: +N/A` — that is the _healthy_ result —
   and `Framework Size` is `N/A` on every run, because the script measures an embedded
   `Frameworks/Rokt_Widget.framework` that this statically-linked app never produces. Only `N/A`
   in the per-branch columns means the measurement itself broke.
6. If you ever pipe `xcodebuild` through `xcpretty` or `xcbeautify`, set `pipefail` first —
   otherwise `$?` is the formatter's status and a failed build reports success. No script here
   does that today; keep it that way.
7. Xcode is pinned per workflow through `maxim-lobanov/setup-xcode`. There is no
   `.xcode-version`, and the workflows do **not** all pin the same version, so copy the
   `-destination` and toolchain flags from the workflow you are mirroring rather than inventing
   them. The destination names a current-generation iPhone with `OS=latest`; an older local Xcode
   may have no matching runtime even though `swift package resolve` succeeds.
8. `-quiet` and `-retry-tests-on-failure` hide a lot. The SPM and package test jobs retry, the
   UI test job deliberately does not — see the comment above it in `pull-request.yml`. A red
   unit job has therefore already survived retries; a red UI job is a single attempt.

## Dependencies

- **There is no lockfile.** `Package.resolved` is gitignored, so every CI run re-resolves, and
  `rokt-ux-helper-ios` and `rokt-contracts-apple` are up-to-next-major ranges: a new RoktUXHelper
  2.x release can change this repo's build with no commit here. A green run pins nothing.
- Because of that, `dcui-swift-schema` is pinned **exactly** in `Package.swift` and to the same
  version in `Rokt-Widget.podspec`, and must match the version `rokt-ux-helper-ios` pins —
  DcuiSchema types reach us across RoktUXHelper's public API. Bump all three together.
- Every podspec dependency version must already be published on CocoaPods trunk or Podspec Lint
  fails for reasons unrelated to your change. `MONOREPO.md` has the release ordering.
- A new third-party dependency needs a size and performance justification, and approval. Ask
  first.

## Conventions no config enforces

- The public surface is **additive only**: deprecate, never remove, and give every public symbol
  `///` DocC documentation. No linter checks either of those.
- An `@objc public class` must mark every non-optional stored `public let`/`var` `@objc`. That
  rule lives in the repo-local `objc-prop-check` linter under `.trunk/scripts/`, not in
  `.swiftlint.yml`, so grepping the SwiftLint config will not find it. Optionals and `override`
  are exempt.
- New Quick specs: reuse `kPipelineWaitTimeout` and `expectEventuallyRecorded` from
  `Example/Tests/QuickSpec+Extension.swift` instead of writing per-assertion `timeout:` values.
  Sequential per-assertion budgets are what made these specs flake — the first assertion absorbs
  the whole pipeline latency. Two of those waits already fill the `ui-test` job's
  `-default-test-execution-time-allowance`, so a spec in which both fail is killed by the per-test
  timeout before it names the failing assertion: do not chain a third, and do not raise the shared
  value. Stick to XCTest, Quick and Nimble; do not add another test framework.
- Do not raise the minimum deployment target, drop an OS version, or make a breaking API change
  without asking. Same for touching CI YAML. Add a comment only when the code cannot be made
  clear instead.

## Commits, pull requests and merge gates

- Base branch is `main`. `master` still exists but is abandoned — nothing has merged into it
  since the trunk moved, so never target it. Patch releases for older majors go on
  `maintenance/*`.
- Conventional-commit subjects (`feat:`, `fix:`, `perf:`, `ci:`, `docs:`, `test:` …) and a
  matching `<type>/<description>` branch name. **Nothing enforces either** — there is no
  semantic-title or branch-name check — but `CHANGELOG.md` is generated from commit history, so
  the subject line is what ships in the release notes.
- Do **not** hand-edit `CHANGELOG.md` in a feature or fix PR. `release-draft.yml` regenerates it
  and opens the release PR; `release-publish.yml` publishes from it. There is no per-PR
  changelog step.
- Use `.github/pull_request_template.md` as the description skeleton.
- The default-branch ruleset requires only a subset of the Pull Request workflow's jobs — Trunk
  Check, SPM Unit Tests, UI Tests and Consumer Test (PactSwift). Podspec Lint, Package SPM Tests,
  Periphery Scan and SDK Size Report are advisory and can be red on a mergeable PR. Re-check the
  ruleset before relying on that split.
- Merges are squash-only, need a CODEOWNERS approval from `@ROKT/sdk-engineering` with every
  review thread resolved, and **any push dismisses existing approvals** — finish pushing before
  you ask for review.

## Secret scanning

Trufflehog runs inside `trunk check`, pinned below its latest release because a newer detector
reports XCTest method names as verified credentials — the reason is in `.trunk/trunk.yaml`. It
catches secrets, not PII: nothing in CI checks the P1 items below, including PII in JSON test
fixtures.

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
