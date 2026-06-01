# Monorepo layout

This repository is the **canonical** home for the Rokt iOS SDK (`Rokt-Widget`) and includes **git subtree** copies of:

- [`Packages/rokt-ux-helper-ios/`](Packages/rokt-ux-helper-ios/) → mirrored to [ROKT/rokt-ux-helper-ios](https://github.com/ROKT/rokt-ux-helper-ios)
- [`Packages/rokt-payment-extension-ios/`](Packages/rokt-payment-extension-ios/) → mirrored to [ROKT/rokt-payment-extension-ios](https://github.com/ROKT/rokt-payment-extension-ios)

[`Packages/matrix.json`](Packages/matrix.json) drives **Release – Publish** mirror and CocoaPods steps (same idea as mParticle’s `Kits/matrix.json`). Add a new object to the array to onboard another subtree mirror; use `cocoapods_publish_order` so trunk pushes stay in the right order before `Rokt-Widget`.

## Matrix fields

| Field                     | Purpose                                                                           |
| ------------------------- | --------------------------------------------------------------------------------- |
| `name`                    | Job label / `git subtree` split branch suffix                                     |
| `local_path`              | Monorepo prefix for `git subtree split`                                           |
| `dest_org`, `dest_repo`   | Mirror GitHub `owner/repo`                                                        |
| `podspec`                 | Path to podspec for `pod trunk push`                                              |
| `changelog_file`          | Changelog used for mirror GitHub release notes (usually root `CHANGELOG.md`)      |
| `cocoapods_publish_order` | Lower runs first in the sequential trunk job                                      |
| `pod_trunk_name`          | CocoaPods trunk API name for `wait_for_pod_version_on_trunk` before `Rokt-Widget` |
| `mirror_force_push_main`  | If `true`, `git push --force` to mirror `main` (one-time / recovery only)         |

The matrix must stay a **non-empty** JSON array so the mirror matrix job has at least one leg.

## Single ecosystem version

**Root `VERSION` is the single source of truth.** On every release, the same semver is written to:

- `VERSION` (Rokt-Widget)
- `Packages/rokt-ux-helper-ios/VERSION` and `Packages/rokt-payment-extension-ios/VERSION`
- `Rokt-Widget.podspec`, `RoktUXHelper.podspec`, and `RoktPaymentExtension.podspec` (`s.version`)

Mirrors and CocoaPods tags for the standalone repos use **that same version** as `rokt-sdk-ios`.

Partners who previously consumed **RoktUXHelper** on an independent **0.x** line must move to **the same major/minor/patch as the Rokt iOS SDK** (update SPM or CocoaPods constraints accordingly).

## Swift Package Manager

Root [`Package.swift`](Package.swift) depends on UX Helper via a **local** package path (`Packages/rokt-ux-helper-ios`). Partners consuming UX Helper or the payment extension from GitHub still use the standalone URLs; those repos receive subtree mirrors and tags aligned with this monorepo’s `VERSION`.

## Pull request checks

[Pull Request](.github/workflows/pull-request.yml) runs **`xcodebuild test`** from the root of each [`Packages/matrix.json`](Packages/matrix.json) `local_path` (same pattern as [mParticle kit SPM tests](https://github.com/mParticle/mparticle-apple-sdk/blob/main/.github/workflows/build-kits.yml)): resolve SwiftPM dependencies, derive the Xcode scheme from `Package.swift` (single-library packages use the package `name` as the scheme), then run that package’s unit tests on the iOS Simulator alongside the root `Rokt-Widget` SPM tests and Example scheme tests.

**Podspec lint** runs `pod lib lint Rokt-Widget.podspec` with `--include-podspecs=Packages/rokt-ux-helper-ios/RoktUXHelper.podspec` so `RoktUXHelper (= VERSION)` resolves from the monorepo; that version is not required to exist on CocoaPods trunk until **Release – Publish** pushes the mirrored pods.

**Periphery** (`.periphery.yml`) sets `exclude_tests: true` and excludes the **`RoktUXHelper`** / **`RoktPaymentExtension`** SPM targets (and their test targets). The Example app builds those packages but does not reference most of their symbols, which would otherwise produce false positives; the scan stays focused on **`Rokt_Widget`** (and the app) via the existing baseline.

1. **Draft**: [Release – Draft](.github/workflows/release-draft.yml) — bump type only. Opens a PR that bumps the ecosystem version everywhere above and updates the root `CHANGELOG.md` (with `kits-path: Packages` for scoped entries).
2. **Publish**: [Release – Publish](.github/workflows/release-publish.yml) runs when **`VERSION`** (root) or root **`CHANGELOG.md`** changes on `main` / `maintenance/*`.

**Release – Publish** (same commit / same version):

- GitHub release + XCFramework on **this** repo (`rokt-sdk-ios`).
- **`Packages/matrix.json`** is loaded once; each row runs a **parallel** mirror job (subtree split → push → GitHub release on that mirror, tag = root `VERSION`). Release notes come from each row’s `changelog_file` (typically root `CHANGELOG.md`).
- One **sequential** job runs `pod trunk push` for each row’s `podspec`, ordered by `cocoapods_publish_order`.
- **Rokt-Widget** publishes last; before that, the workflow waits on trunk for each row’s `pod_trunk_name` at the ecosystem version (`Rokt-Widget.podspec` pins `RoktUXHelper` with `s.version.to_s`).

### GitHub App access

The release GitHub App (`SDK_RELEASE_GITHUB_APP_ID` / `SDK_RELEASE_GITHUB_APP_PRIVATE_KEY`) must have **contents: write** on `rokt-ux-helper-ios` and `rokt-payment-extension-ios` under **ROKT**, plus any existing repos (e.g. `rokt-docs`, `rokt-demo-ios`).

### First-time subtree mirror

If a mirror’s `main` is not subtree-compatible, a **one-time** force-push may be required. Prefer an empty mirror or subtree-only history for the first automated push.

## Updating a subtree from upstream

```bash
git subtree pull --prefix=Packages/rokt-ux-helper-ios https://github.com/ROKT/rokt-ux-helper-ios.git main --squash
```

Use the same pattern for `Packages/rokt-payment-extension-ios`. Resolve conflicts, align versions with root `VERSION` if needed, then merge.

## Related pattern

Similar in spirit to [mParticle’s Apple SDK monorepo](https://github.com/mParticle/mparticle-apple-sdk) (subtree split, mirrors, ordered CocoaPods), with **one shared semver** for the Rokt iOS SDK and its mirrored packages.
