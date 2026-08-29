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

| Task                          | Command                                                                                         |
| ----------------------------- | ----------------------------------------------------------------------------------------------- |
| Lint and format as CI does    | `trunk check --all`; `trunk fmt` to apply                                                       |
| Unit tests only               | `xcodebuild test -scheme Rokt-Widget -only-testing:Rokt_WidgetTests -destination '<simulator>'` |
| The specs CI calls "UI Tests" | `xcodebuild test -project Example/rokt.xcodeproj -scheme rokt-Example-MOCK -destination '…'`    |
| Consumer contract only        | `xcodebuild test -scheme Rokt-Widget -only-testing:ContractTests` with `PACT_OUTPUT_DIR` set    |
| Unused-code scan              | index-store build first, then `periphery scan` — see trap 4                                     |
| SDK size delta                | `Tests/SizeReport/measure_size.sh` (`--json` for the CI shape)                                  |

Copy the exact `-destination` and toolchain flags from `.github/workflows/pull-request.yml`
rather than inventing them.

### Command traps

1. `trunk check` with no arguments checks **only files changed against the upstream branch**,
   while CI runs the Trunk action with `check-mode: all`. A pre-existing violation in a file you
   never touched is green locally and red in CI. Run `trunk check --all` before pushing.
2. `xcodebuild test -scheme Rokt-Widget` runs **both** SPM test targets, `ContractTests`
   included. Those need `PACT_OUTPUT_DIR`; CI supplies it as `TEST_RUNNER_PACT_OUTPUT_DIR`,
   whose prefix the simulator strips on arrival, and `pacts/` is gitignored. Pass
   `-only-testing:Rokt_WidgetTests` when you only want unit tests.
3. There is no XCUITest in this repo. `Example/rokt.xcodeproj` has exactly two targets,
   `rokt_Example` and `rokt_Tests`; the "UI Tests" job runs the Quick/Nimble specs in
   `Example/Tests/` through the `rokt-Example-MOCK` scheme. The `rokt-Example` and
   `rokt-Example-STAGE` schemes still list a `rokt_ExampleUITests` testable that no longer
   exists as a target — skipped in the former, not skipped in the latter. Use
   `rokt-Example-MOCK`, which is the scheme CI actually exercises.
4. Bare `periphery scan` cannot work here. `.periphery.yml` sets `skip_build: true` and reads a
   pre-built index store out of `DerivedData-periphery/`, so run the workflow's indexing build
   first — same `-derivedDataPath`, with the two index-store build settings the Periphery Scan
   job passes. It is also `strict: true` with a baseline file: pre-existing findings are
   suppressed, new ones fail. Fix the finding rather than widening the baseline.
5. **The size report cannot fail a PR.** `measure_size.sh` falls back from `archive` to `build`
   and, if both fail, reports 0 KB instead of erroring; the CI job additionally wraps both
   measurement steps in `continue-on-error: true`. A delta of `N/A` or `0` means the build
   broke, not that your change is free.
6. If you ever pipe `xcodebuild` through `xcpretty` or `xcbeautify`, set `pipefail` first —
   otherwise `$?` is the formatter's status and a failed build reports success. No script here
   does that today; the multi-command workflow steps use `set -euo pipefail`, so keep any new
   one consistent.
7. Xcode is pinned per workflow through `maxim-lobanov/setup-xcode`. There is no
   `.xcode-version`, and the workflows do **not** all pin the same version, so
   `grep xcode-version .github/workflows/` before assuming a toolchain. The simulator
   destination names a current-generation iPhone with `OS=latest`; an older local Xcode may have
   no matching runtime even though `swift package resolve` succeeds.
8. `-quiet` and `-retry-tests-on-failure` hide a lot. The SPM and package test jobs retry, the
   UI test job deliberately does not — see the comment above it in `pull-request.yml`. A red
   unit job has therefore already survived retries; a red UI job is a single attempt.

## Dependencies

- **There is no lockfile.** `Package.resolved` is gitignored, so every CI run re-resolves, and
  `rokt-ux-helper-ios` and `rokt-contracts-apple` are up-to-next-major ranges: a new RoktUXHelper
  2.x release can change this repo's build with no commit here. A green run pins nothing.
- Because of that, `dcui-swift-schema` is pinned **exactly** in `Package.swift` and to the same
  version in `Rokt-Widget.podspec`, and must match the version `rokt-ux-helper-ios` pins:
  DcuiSchema types reach us across RoktUXHelper's public API, so we link it directly. Bump all
  three together.
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
  the whole pipeline latency. Keep any such budget under half the `ui-test` job's
  `-default-test-execution-time-allowance`, or the per-test timeout kills the run before it names
  the failing assertion. Stick to XCTest, Quick and Nimble; do not add another test framework.
- Do not raise the minimum deployment target, drop an OS version, or make a breaking API change
  without asking. Same for touching CI YAML. Add a comment only when the code cannot be made
  clear instead.

## Commits, pull requests and merge gates

- Base branch is `main`. `master` still exists and is more than a year stale — never target it.
  Patch releases for older majors go on `maintenance/*`.
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

## Security review

- No hardcoded secrets or credentials. Trufflehog runs inside `trunk check`, pinned below its
  latest release because a newer detector reports XCTest method names as verified credentials;
  the reason is in `.trunk/trunk.yaml`.
- No real customer PII in code, tests or fixtures, hashed included. Nothing enforces this.
- Validate and sanitise anything crossing a trust boundary, including data decoded from a
  network response.
