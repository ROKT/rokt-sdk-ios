# SDK Size Report

Measures the Rokt SDK's impact on app size by comparing a baseline app (no SDK) against one with the SDK integrated.

## How It Works

1. `measure_size.sh` builds two test apps using the **local SPM package**
2. The SDK framework is embedded in the with-SDK app bundle
3. Reports the size delta (framework + resources)

## Usage

```bash
./measure_size.sh                  # Human-readable output
./measure_size.sh --json           # JSON output for CI
./measure_size.sh --with-sdk-only  # Only measure with-SDK app
```

## Test Apps

- **SizeTestApp** - Minimal SwiftUI app (baseline)
- **SizeTestAppWithSDK** - Same app with Rokt SDK integrated following the [integration guide](https://docs.rokt.com/developers/integration-guides/ios/how-to/integrating-and-initializing)

## CI Integration

The `.github/workflows/size_report.yml` workflow runs on PRs to report size changes.

## Example Measurements

Run `./measure_size.sh` for current values. These are example measurements as of January 2026:

| Metric           | Size    |
| ---------------- | ------- |
| Total SDK Impact | ~5 MB   |
| Framework Size   | ~4.8 MB |
| Resources        | ~176 KB |
