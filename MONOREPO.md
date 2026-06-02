# Monorepo layout

This repository is the **canonical** home for the Rokt iOS SDK (`Rokt-Widget`) and includes a **git subtree** copy of:

- [`Packages/rokt-payment-extension-ios/`](Packages/rokt-payment-extension-ios/) → mirrored to [ROKT/rokt-payment-extension-ios](https://github.com/ROKT/rokt-payment-extension-ios)

The SDK depends on **RoktUXHelper** via [`rokt-ux-helper-ios`](https://github.com/ROKT/rokt-ux-helper-ios): see [`Package.swift`](Package.swift) and `Rokt-Widget.podspec`.

[`Packages/matrix.json`](Packages/matrix.json) drives **Release – Publish** mirror and CocoaPods steps for the payment extension only (same idea as mParticle’s `Kits/matrix.json`). Add a new object to the array to onboard another subtree mirror; use `cocoapods_publish_order` so trunk pushes stay in the right order before `Rokt-Widget`.

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
- `Packages/rokt-payment-extension-ios/VERSION`
- `Rokt-Widget.podspec` and `RoktPaymentExtension.podspec` (`s.version` for the widget and payment extension)

`Rokt-Widget.podspec` declares **`RoktUXHelper`** for CocoaPods (see podspec); that library is released from [`rokt-ux-helper-ios`](https://github.com/ROKT/rokt-ux-helper-ios).

Mirrors and CocoaPods tags for the payment extension use **that same version** as `rokt-sdk-ios`.

## Swift Package Manager

Partners consume **RoktUXHelper** from [`github.com/ROKT/rokt-ux-helper-ios`](https://github.com/ROKT/rokt-ux-helper-ios) (SPM or CocoaPods). This repo resolves it as a **remote** Swift package dependency (`Package.swift`).

## Pull request checks

[Pull Request](.github/workflows/pull-request.yml) runs **`xcodebuild test`** from the root of each [`Packages/matrix.json`](Packages/matrix.json) `local_path` for mirrored packages (same pattern as [mParticle kit SPM tests](https://github.com/mParticle/mparticle-apple-sdk/blob/main/.github/workflows/build-kits.yml)), alongside the root `Rokt-Widget` SPM tests and Example scheme tests.

**Podspec lint** runs `pod lib lint Rokt-Widget.podspec` against CocoaPods trunk; **`RoktUXHelper`** must satisfy the range declared in `Rokt-Widget.podspec` (see podspec).

**Periphery** (`.periphery.yml`) sets `exclude_tests: true` and excludes **`RoktPaymentExtension`** (and its test target) so the Example app does not produce false positives for that vendored kit.

## Release flow

1. **Draft**: [Release – Draft](.github/workflows/release-draft.yml) — bump type only. Opens a PR that bumps the ecosystem version everywhere above and updates the root `CHANGELOG.md` (with `kits-path: Packages` for scoped entries).
2. **Publish**: [Release – Publish](.github/workflows/release-publish.yml) runs when **`VERSION`** (root) or root **`CHANGELOG.md`** changes on `main` / `maintenance/*`.

**Release – Publish** (same commit / same version):

- GitHub release + XCFramework on **this** repo (`rokt-sdk-ios`).
- **`Packages/matrix.json`** is loaded once; each row runs a **parallel** mirror job (subtree split → push → GitHub release on that mirror, tag = root `VERSION`).
- One **sequential** job runs `pod trunk push` for each row’s `podspec`, ordered by `cocoapods_publish_order`.
- **Rokt-Widget** publishes last; the workflow waits on trunk for each matrix `pod_trunk_name` at the ecosystem version, then validates and pushes `Rokt-Widget.podspec` (which must resolve **`RoktUXHelper`** on trunk within the declared range).

### GitHub App access

The release GitHub App (`SDK_RELEASE_GITHUB_APP_ID` / `SDK_RELEASE_GITHUB_APP_PRIVATE_KEY`) must have **contents: write** on `rokt-payment-extension-ios` under **ROKT** for subtree mirroring, plus any existing repos (e.g. `rokt-docs`, `rokt-demo-ios`).

### First-time subtree mirror

If a mirror’s `main` is not subtree-compatible, a **one-time** force-push may be required. Prefer an empty mirror or subtree-only history for the first automated push.

## Updating the payment subtree from upstream

```bash
git subtree pull --prefix=Packages/rokt-payment-extension-ios https://github.com/ROKT/rokt-payment-extension-ios.git main --squash
```

Resolve conflicts, align versions with root `VERSION` if needed, then merge.

## Related pattern

Similar in spirit to [mParticle’s Apple SDK monorepo](https://github.com/mParticle/mparticle-apple-sdk) (subtree split, mirrors, ordered CocoaPods), with **one shared semver** for the Rokt iOS SDK and its mirrored payment extension.
