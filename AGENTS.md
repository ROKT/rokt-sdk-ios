# Rokt iOS SDK (rokt-sdk-ios)

## Project Overview

This is the **public distribution repository** for the Rokt iOS SDK (`Rokt-Widget`). It does not contain source code — it hosts the pre-built `Rokt_Widget.xcframework.zip` binary and the distribution manifests consumed by Swift Package Manager (SPM) and CocoaPods. The actual SDK source lives in a separate internal repository; this repo serves as the release artifact delivery mechanism for iOS integrators.

Owned by the **sdk-engineering** team. Cortex tag: `iOS-spm-sdk`, service tier 3. On-call: OpsGenie schedule `Mobile Integrations_schedule`.

## Architecture

```text
Internal SDK repo (source)
        │
        ▼  (CI builds xcframework)
rokt-sdk-ios (this repo)
   ├── Rokt_Widget.xcframework.zip   ← pre-built binary artifact
   ├── Package.swift                 ← SPM binary target manifest
   ├── Rokt-Widget.podspec           ← CocoaPods spec
   └── VERSION / CHANGELOG.md        ← version tracking
        │
        ▼  (GitHub Actions on VERSION change)
   GitHub Release ─► CocoaPods trunk push
                 └─► Triggers rokt-demo-ios release
```

When a new version is ready, the `VERSION` file and `CHANGELOG.md` are updated on `main` along with the new xcframework zip. The GitHub Actions workflow detects the `VERSION` change and:

1. Creates a GitHub Release with the xcframework zip attached
2. Validates and publishes the podspec to CocoaPods trunk
3. Dispatches a `release-build` event to `ROKT/rokt-demo-ios` to trigger a demo app release

## Tech Stack

- **Language**: Swift 5.0+ (SDK consumers)
- **Swift tools version**: 5.3 (Package.swift)
- **Minimum iOS deployment target**: iOS 12.0 (CocoaPods), iOS 10.0 (SPM manifest — legacy)
- **Distribution formats**: Swift Package Manager (binary target), CocoaPods
- **CI/CD**: GitHub Actions (release workflow), Buildkite (pipeline slug: `ios-spm`)
- **Ruby**: 3.2.2 (for CocoaPods publishing in CI)

## Distribution & Installation

### Swift Package Manager

In Xcode: File > Add Packages, enter `https://github.com/ROKT/rokt-sdk-ios.git`.

Or add to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ROKT/rokt-sdk-ios.git", .upToNextMajor(from: "4.16.1"))
]
```

### CocoaPods

The pod is published as `Rokt-Widget`. Add to your Podfile:

```ruby
pod 'Rokt-Widget'
```

## CI/CD Pipeline

### GitHub Actions: `release-from-main.yml`

Triggers on push to `main` when the `VERSION` file changes.

| Job | Runs on | Steps |
|---|---|---|
| `release-rokt-sdk` | `ubuntu-latest` | Reads VERSION, extracts changelog, creates GitHub Release with xcframework zip |
| `publish-rokt-sdk` | `macos-latest` | Installs CocoaPods (Ruby 3.2.2), validates podspec (`pod spec lint`), publishes to trunk (`pod trunk push`) |
| `trigger-demo-app-release` | `ubuntu-latest` | Generates GitHub App token, dispatches `release-build` event to `ROKT/rokt-demo-ios` |

### Buildkite

Pipeline slug: `ios-spm` (referenced in Cortex catalog).

## Project Structure

| Path | Purpose |
|---|---|
| `Package.swift` | SPM package manifest — defines `Rokt-Widget` library with binary target pointing to the xcframework zip on GitHub Releases |
| `Rokt-Widget.podspec` | CocoaPods spec for publishing `Rokt-Widget` pod |
| `Rokt_Widget.xcframework.zip` | Pre-built xcframework binary artifact |
| `VERSION` | Single-line file containing the current SDK version (e.g., `4.16.1`) |
| `CHANGELOG.md` | Release notes following Keep a Changelog format |
| `.github/workflows/release-from-main.yml` | GitHub Actions release pipeline |
| `.cortex/catalog/ios-spm.yaml` | Cortex service catalog definition |
| `.github/CODEOWNERS` | Code ownership (`@ROKT/sdk-engineering`) |

## Release Process

1. Update `VERSION` file with new version number
2. Update `CHANGELOG.md` with release notes under the new version heading
3. Update `Package.swift` binary target URL and checksum for the new xcframework zip
4. Update `Rokt-Widget.podspec` version
5. Replace `Rokt_Widget.xcframework.zip` with the new build artifact
6. Merge to `main` — the GitHub Actions workflow handles the rest

## Observability

- **Datadog Dashboard**: [Mobile SDK Detailed Error View](https://rokt.datadoghq.com/dashboard/nsi-c8c-gtd)

## Team Ownership

- **CODEOWNERS**: `@ROKT/sdk-engineering`
- **Cortex owner**: `sdk-engineering` group
- **On-call**: OpsGenie schedule `Mobile Integrations_schedule`
- **Contact**: nativeappsdev@rokt.com

## Maintaining This Document

When making changes to this repository that affect the information documented here
(build commands, dependencies, architecture, deployment configuration, etc.),
please update this document to keep it accurate. This file is the primary reference
for AI coding assistants working in this codebase.
