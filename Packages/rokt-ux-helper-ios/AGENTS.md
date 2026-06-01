# Agent Guide

Instructions for AI coding agents (Claude Code, Codex, etc.) working in this repository. Human contributors should still read [README.md](./README.md), [TESTING.md](./TESTING.md), and [RELEASING.md](./RELEASING.md).

## Project overview

`RoktUXHelper` is a Swift package that renders Rokt experiences inside partner iOS apps (SwiftUI + UIKit). It is distributed via SPM and CocoaPods. The library targets **iOS 15.0+**. See [README.md](./README.md) for the architecture diagram and a description of the core components (`RoktUX`, `LayoutTransformer`, `CreativeSyntaxMapper`, `LayoutSchemaViewModel`, `LayoutState`).

## Repository layout

- `Sources/RoktUXHelper/` — library source.
- `Tests/RoktUXHelperTests/` — unit and snapshot tests. Snapshot references live alongside the tests in `__Snapshots__/`.
- `Example/` — example host app demonstrating SwiftUI and UIKit integration.
- `.github/workflows/` — CI (pull request checks) and release automation.
- `tools/` — local tooling and scripts.

## Working on a feature branch

1. **Branch naming and commits** — use conventional commit style for both branch names and PR titles (e.g. `feat(richtext): support <p> tag`, `fix(catalog-device-pay): prevent duplicate taps`). The release-draft workflow parses PR titles to generate the changelog, so accurate type/scope matters.
2. **Tests** — open `Package.swift` in Xcode and run `⌘U`, or from the CLI:

   ```bash
   set -o pipefail && xcodebuild -skipPackagePluginValidation -scheme RoktUXHelper \
     -destination 'platform=iOS Simulator,name=iPhone 16' \
     -derivedDataPath DerivedData test | xcbeautify
   ```

   Do **not** use `swift test` — the library imports `UIKit`, which is unavailable in the host SPM build and the command will fail. To scope to a single suite, append `-only-testing:RoktUXHelperTests/TestRowComponent`. Add tests for new behaviour.

3. **Snapshot tests** — visual regressions are caught by `swift-snapshot-testing`; reference PNGs live next to each test in `__Snapshots__/`. To intentionally update a snapshot, either delete the offending PNG and re-run the test (it re-records on first run), or set `isRecording = true` in the test's `setUp()`, re-run, then **remove the flag before committing** (never commit `isRecording = true`). On CI failure, download the `snapshot-failures` artifact for actual-vs-expected diffs. See [TESTING.md](./TESTING.md) for the full workflow and coverage matrix.
4. **Schema bumps** — if you change the `DcuiSchema` dependency, also bump `Constants.layoutSchemaVersion` in `Sources/RoktUXHelper/Data/Model/RoktIntegrationInfoDetails.swift` so `SchemaVersionConsistencyTests` passes. README has the full steps.
5. **Public API changes** — update [MIGRATING.md](./MIGRATING.md) when you rename or remove public symbols.
6. **PR template** — fill in the sections in `.github/pull_request_template.md` (background, what changed, screenshots if UI, checklist).

## CHANGELOG.md is auto-generated — do not edit it

`CHANGELOG.md` is produced automatically by the [`Release – Draft`](https://github.com/ROKT/rokt-ux-helper-ios/actions/workflows/release-draft.yml) GitHub Actions workflow, which calls `ROKT/rokt-workflows/actions/generate-changelog` and builds entries from the git history (conventional commit PR titles).

**Do not modify `CHANGELOG.md` on feature branches.** Any manual edits will be overwritten when the next release PR is drafted. If you want your change to appear in the release notes:

- Write a clear, conventional commit-style **PR title** (e.g. `feat(richtext): support <ul>, <ol>, <li>`).
- That title becomes the changelog entry at release time — no further action needed.

See [RELEASING.md](./RELEASING.md) for the full release flow.

## Files you generally should not touch

- `CHANGELOG.md` — auto-generated (see above).
- `VERSION` — bumped by the `Release – Draft` workflow.
- `RoktUXHelper.podspec` version field — also bumped by the release workflow.
- `Package.resolved` — only changes when dependency versions change.
- `Tests/.../__Snapshots__/*.png` — only regenerate intentionally; see [TESTING.md](./TESTING.md).

## Verification before opening a PR

- Build and run the unit + snapshot tests locally.
- If you changed UI rendering, inspect snapshot diffs (delete the relevant `__Snapshots__/*.png`, re-run to re-record, eyeball the output, commit the new PNGs).
- Confirm the example app in `Example/` still builds against your changes.

## Releases

Releases are driven entirely by the `Release – Draft` → merge → `Release – Publish` workflow chain. Agents should not create release commits, edit `CHANGELOG.md`, or bump `VERSION` directly. See [RELEASING.md](./RELEASING.md).
