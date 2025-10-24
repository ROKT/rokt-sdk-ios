<!-- markdownlint-disable MD024 -->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/2.0.0.html).

## [Unreleased]

- RoktUXHelper version 0.7.4
- New animation styles supported in DataImageCarousel

### Fixed

- Fixed ProgressComponent

## [4.14.2] - 2025-10-24

## [4.14.1] - 2025-09-22

### Fixed

- Fixed thread safety crash in DistributionComponents when transitioning between offers

## [4.14.0] - 2025-08-22

### Fixed

- Handle negative values in `Progression` predicate of `When` component

## [4.13.0] - 2025-08-19

### Changed

- UX Helper version updated to [0.7.0](https://github.com/ROKT/rokt-ux-helper-ios/blob/main/CHANGELOG.md#070---2025-08-19)

## [4.12.1] - 2025-08-08

### Changed

- Add Discover to supported Apple Pay networks

## [4.12.0] - 2025-08-05

### Added

- Add detection of Stripe SDK with Apple Pay capabilities

### Fixed

- Debounce embedded size change events
- Persist `sessionId` from API response regardless of whether layouts are selected

## [4.11.0] - 2025-06-19

### Added

- EmbeddedSizeChanged now gets emitted as an event

### Changed

- FirstPositiveEngagement is now emitted for all execute calls

## [4.10.0] - 2025-05-28

### Changed

- Enabled DSym on XCFramework export
- Add detection of Apple Pay and if a user is new to Apple Pay
- Sessions are now retained between app restarts

## [4.9.1] - 2025-04-05

### Added

- Explicitly add @objc annotation to support Cart Item Instant Purchase

## [4.9.0] - 2025-04-04

### Added

- Support for openURL passthrough option
- Thank you upsells layout
- Image carousel layout

## [4.8.1] - 2025-02-27

### Fixed

- Limit size dimensions to 2 decimal places to fix precision issue

## [4.8.0] - 2025-02-05

### Removed

- Remove spacing when image download fails

### Fixed

- Fix color mode switch on RichText after progression

## [4.7.0] - 2024-12-17

### Added

- iOS SDK using UXHelper module as rendering engine

### Changed

- Minimum supported iOS version bumped to 12 (deprecated support for iOS 11 & 10)

## [4.6.1] - 2024-10-31

### Fixed

- Fixed regression on weight property
- Flutter embedded overlap fix released behind feature flag
- Fixed carousel height
- Refactored dynamic-height bottomsheet to fix onLoad callback
- Added Flutter iOS arm64 simulator support

## [4.6.0] - 2024-09-27

### Fixed

- Dynamic bottomsheet enhancements
- Fixed accessibility text cut-off
- Fixed carousel distribution height on iOS 18

## [4.5.1] - 2024-08-23

### Fixed

- Fixed bottomsheet bottom-edge background color
- Fixed system font accessibility sizing

## [4.5.0] - 2024-08-09

### Added

- Support for dynamic-height bottomsheet

## [4.4.0] - 2024-07-03

### Added

- Support collapsing the embedded layout with the close button

### Fixed

- Fix color mode changes on the RichText component after progression
- Fix Arabic/Farsi localized numbers in event dates

## [4.3.1] - 2024-05-23

### Fixed

- Fix Flutter embedded placement not tappable on second offer
- Add extra is-Rokt URL parameters under feature flag
- Bounding box rendering under feature flag
- Fix retry logic on nil-response in networking layer

## [4.3.0] - 2024-04-23

### Fixed

- Fix empty Flutter embedded placement height
- Fix RoktWebview menu on iPadOS
- Align StaticImage dark-URL behavior with Android
- Align overlay vertical-alignment key with Android and Web

## [4.2.0] - 2024-03-13

### Added

- Privacy Manifest support

### Fixed

- Fix overlay alignment

## [4.1.0] - 2024-02-26

### Fixed

- Re-register fonts and log on font errors
- Fix dark-mode switch on iOS 17
- Fix crash on text progress indicator
- Fix creative title rendering twice
- Fix crash on negative response
- Fix threading crash in BaseDependencyInjection sharedItems
- Open linked URLs from bottomsheet in full-screen height

[unreleased]: https://github.com/ROKT/rokt-sdk-ios/compare/4.14.2...HEAD
[4.14.2]: https://github.com/ROKT/rokt-sdk-ios/compare/4.14.1...4.14.2
[4.14.1]: https://github.com/ROKT/rokt-sdk-ios/compare/4.14.0...4.14.1
[4.14.0]: https://github.com/ROKT/rokt-sdk-ios/compare/4.13.0...4.14.0
[4.13.0]: https://github.com/ROKT/rokt-sdk-ios/compare/4.12.1...4.13.0
[4.12.1]: https://github.com/ROKT/rokt-sdk-ios/compare/4.12.0...4.12.1
[4.12.0]: https://github.com/ROKT/rokt-sdk-ios/compare/4.11.0...4.12.0
[4.11.0]: https://github.com/ROKT/rokt-sdk-ios/compare/4.10.0...4.11.0
[4.10.0]: https://github.com/ROKT/rokt-sdk-ios/compare/4.9.1...4.10.0
[4.9.1]: https://github.com/ROKT/rokt-sdk-ios/compare/4.9.0...4.9.1
[4.9.0]: https://github.com/ROKT/rokt-sdk-ios/compare/4.8.1...4.9.0
[4.8.1]: https://github.com/ROKT/rokt-sdk-ios/compare/4.8.0...4.8.1
[4.8.0]: https://github.com/ROKT/rokt-sdk-ios/compare/4.7.0...4.8.0
[4.7.0]: https://github.com/ROKT/rokt-sdk-ios/compare/4.6.1...4.7.0
[4.6.1]: https://github.com/ROKT/rokt-sdk-ios/compare/4.6.0...4.6.1
[4.6.0]: https://github.com/ROKT/rokt-sdk-ios/compare/4.5.1...4.6.0
[4.5.1]: https://github.com/ROKT/rokt-sdk-ios/compare/4.5.0...4.5.1
[4.5.0]: https://github.com/ROKT/rokt-sdk-ios/compare/4.4.0...4.5.0
[4.4.0]: https://github.com/ROKT/rokt-sdk-ios/compare/4.3.1...4.4.0
[4.3.1]: https://github.com/ROKT/rokt-sdk-ios/compare/4.3.0...4.3.1
[4.3.0]: https://github.com/ROKT/rokt-sdk-ios/compare/4.2.0...4.3.0
[4.2.0]: https://github.com/ROKT/rokt-sdk-ios/compare/4.1.0...4.2.0
[4.1.0]: https://github.com/ROKT/rokt-sdk-ios/compare/4.0.11-beta.9...4.1.0
