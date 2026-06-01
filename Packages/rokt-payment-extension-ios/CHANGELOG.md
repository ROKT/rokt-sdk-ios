<!-- markdownlint-disable MD024 -->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.3] - 2026-05-18

### Fixed

- Preserve address line 2 in Stripe billing/shipping ([#27](https://github.com/ROKT/rokt-payment-extension-ios/pull/27))

### Changed

- Bump trunk-io/trunk-action from 1.2.4 to 1.3.1 ([#25](https://github.com/ROKT/rokt-payment-extension-ios/pull/25))
- Bump actions/create-github-app-token from 3.1.1 to 3.2.0 ([#26](https://github.com/ROKT/rokt-payment-extension-ios/pull/26))

## [2.0.2] - 2026-05-12

### Fixed

- Add Stripe failure identifiers ([#23](https://github.com/ROKT/rokt-payment-extension-ios/pull/23))
- Include names in Stripe payment details ([#22](https://github.com/ROKT/rokt-payment-extension-ios/pull/22))

## [2.0.1] - 2026-04-24

### Fixed

- Use server total instead of item subtotal in sheet ([#20](https://github.com/ROKT/rokt-payment-extension-ios/pull/20))

### Changed

- Bump `rokt-contracts-apple` to `2.0.0` / `RoktContracts` to `~> 2.0` to
  surface `totalAmount`, `shippingCost`, and `tax` on `PaymentPreparation`

## [2.0.0] - 2026-04-23

### Breaking Changes

- Replace returnURL with urlScheme in payment extension init ([#18](https://github.com/ROKT/rokt-payment-extension-ios/pull/18))

## [1.1.0] - 2026-04-21

### Added

- Upgrade Stripe iOS SDK dependency to 25.x ([#16](https://github.com/ROKT/rokt-payment-extension-ios/pull/16))

## [1.0.0] - 2026-04-20

### Breaking Changes

- Rename to RoktPaymentExtension with flexible init ([#14](https://github.com/ROKT/rokt-payment-extension-ios/pull/14))
- Renamed package, product, class, and CocoaPods pod from `RoktStripePaymentExtension`
  to `RoktPaymentExtension`. Update imports and class references. The GitHub repo has
  been renamed to `rokt-payment-extension-ios`; the old URL auto-redirects but
  consumers should update their `Package.swift` and Podfile.
- `RoktPaymentExtension` initializer parameters are now all optional.
  `applePayMerchantId` is optional — omit to build an Afterpay-only extension.
  `returnURL` is already optional. The initializer still returns `nil` if both are
  omitted or empty.
- `supportedMethods` is now a computed property reflecting the parameters provided
  at init; methods with no backing configuration are no longer advertised.
- Bumped RoktContracts to `~> 1.0` and adopted the new `PaymentContext` parameter
  on `presentPaymentSheet(item:method:context:from:preparePayment:completion:)`.

### Added

- Add Afterpay/Clearpay support via Stripe PaymentHandler ([#10](https://github.com/ROKT/rokt-payment-extension-ios/pull/10))
- `BillingDetailsMapping` helper for translating `ContactAddress` to Stripe billing
  and shipping detail types.
- `handleURLCallback(with:)` implementation forwarding redirect URLs to
  `StripeAPI.handleURLCallback(with:)` so the Rokt SDK can complete in-flight
  Afterpay redirect flows.
- Ability to initialize the extension for Afterpay-only use (no Apple Pay merchant
  ID required).

### Changed

- Bump peter-evans/create-pull-request from 8.1.0 to 8.1.1 ([#12](https://github.com/ROKT/rokt-payment-extension-ios/pull/12))
- Bump actions/create-github-app-token from 3.0.0 to 3.1.1 ([#11](https://github.com/ROKT/rokt-payment-extension-ios/pull/11))
- Align README with Rokt SDK public API (initWith / selectShoppableAds) ([#13](https://github.com/ROKT/rokt-payment-extension-ios/pull/13))

## [0.1.2] - 2026-04-02

### Breaking Changes

- Align with rokt-contracts-apple 0.1.3 breaking API changes ([#8](https://github.com/ROKT/rokt-stripe-payment-extension-ios/pull/8))

### Added

- Initial RoktStripePaymentExtension implementing PaymentExtension from contracts

### Fixed

- Use standard Keep a Changelog format for release automation ([#6](https://github.com/ROKT/rokt-stripe-payment-extension-ios/pull/6))
- Update RoktContracts version and drop v-prefix from release tags ([#1](https://github.com/ROKT/rokt-stripe-payment-extension-ios/pull/1))

### Changed

- Use GitHub App token and shared workflow for trunk upgrade ([#4](https://github.com/ROKT/rokt-stripe-payment-extension-ios/pull/4))
- Upgrade trunk to 1.25.0 ([#3](https://github.com/ROKT/rokt-stripe-payment-extension-ios/pull/3))
- Bump codecov/codecov-action from 5.5.3 to 6.0.0 ([#2](https://github.com/ROKT/rokt-stripe-payment-extension-ios/pull/2))

## [0.1.1] - 2026-04-02

### Added

- Initial RoktStripePaymentExtension implementing PaymentExtension from contracts

### Fixed

- Use standard Keep a Changelog format for release automation ([#6](https://github.com/ROKT/rokt-stripe-payment-extension-ios/pull/6))
- Update RoktContracts version and drop v-prefix from release tags ([#1](https://github.com/ROKT/rokt-stripe-payment-extension-ios/pull/1))

### Changed

- Use GitHub App token and shared workflow for trunk upgrade ([#4](https://github.com/ROKT/rokt-stripe-payment-extension-ios/pull/4))
- Upgrade trunk to 1.25.0 ([#3](https://github.com/ROKT/rokt-stripe-payment-extension-ios/pull/3))
- Bump codecov/codecov-action from 5.5.3 to 6.0.0 ([#2](https://github.com/ROKT/rokt-stripe-payment-extension-ios/pull/2))

## [0.1.0] - 2025-03-25

### Added

- `RoktStripePaymentExtension` implementing `PaymentExtension` protocol from RoktContracts
- Apple Pay support via Stripe's `STPApplePayContext`
- `ContactAddressMapping` for converting Apple Pay contact data to contract types
- Swift Package Manager and CocoaPods support
- GitHub Actions CI (trunk lint, unit tests, podspec lint)
- Dependabot for GitHub Actions dependency updates
