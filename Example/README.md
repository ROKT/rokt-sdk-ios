# Sample app

Open `Example/rokt.xcodeproj` in Xcode to run it by hand. It demonstrates overlay, embedded and
grouped placements across the MOCK, STAGE and PROD configurations.

## Driving it without a human

The app can be configured entirely from launch arguments, so an agent, a UI test or a CI job can
run a placement end to end and read back what the host observed. This exists because a class of
partner report — a placement that renders but then misbehaves — is only reproducible through the
real host path, which no in-process test covers.

### Launch arguments

Every argument has a `ROKT_*` environment-variable equivalent for `xcrun simctl launch`.

| Argument               | Environment variable   | Meaning                                                                          |
| ---------------------- | ---------------------- | -------------------------------------------------------------------------------- |
| `-roktAutoRun 1`       | `ROKT_AUTO_RUN`        | Initialise and show a placement with no taps                                     |
| `-roktTagId <id>`      | `ROKT_TAG_ID`          | Rokt tag id to initialise with                                                   |
| `-roktEnvironment <e>` | `ROKT_ENVIRONMENT`     | `Stage`, `Prod`, `ProdDemo`, `Local`. Omit to keep the build configuration's own |
| `-roktPageIdentifier`  | `ROKT_PAGE_IDENTIFIER` | Page identifier / view name                                                      |
| `-roktLocation <name>` | `ROKT_LOCATION`        | Embedded target element, default `Location1`                                     |
| `-roktAttributes <js>` | `ROKT_ATTRIBUTES`      | JSON object of string attributes                                                 |

Omitting `-roktEnvironment` is deliberate and load-bearing: `Rokt.setEnvironment` replaces the
configuration wholesale, which would take a MOCK build off the offline transports. Leave it unset
to test offline, set it to test against a real account.

No account is committed here. Credentials for the shared test account live in internal
test-account documentation and are passed at run time.

### Offline runs

Under a MOCK configuration the SDK serves init and offers from offline transports, and
`Automation/offers.json` overrides the built-in offers fixture. That fixture is a three-offer
embedded one-by-one targeting `Location1`, with fixed copy, so offer count and button labels are
stable enough to automate against. Adjust the fixture rather than the test if you need a
different shape.

### The transcript

With `-roktAutoRun`, every host-facing `RoktEvent` is recorded as one JSON line — including
`EmbeddedSizeChanged`, the signal a host sizes its container from, and `HostHeights`, the heights
the host's own views actually settled at. Lines go to two places:

- stdout, prefixed `ROKT_TRANSCRIPT`, greppable from `xcodebuild` or `simctl launch --console-pty`
- an on-screen text view with accessibility identifier `rokt-automation-transcript`, which is how
  an out-of-process UI test reads it

The embedded views also carry `rokt-embedded-Location1` … `rokt-embedded-Location4` identifiers,
so a test can measure the SDK's own view independently of the height it published.

### Example

```sh
xcrun simctl launch --console-pty <device> com.rokt.ios-example \
  -roktAutoRun 1 -roktTagId <tagId> -roktPageIdentifier <viewName> -roktLocation Location1
```

### UI tests

`Example/UITests` holds the `rokt_ExampleUITests` bundle, run through the
`rokt-Example-AUTOMATION` scheme:

```sh
xcodebuild test -project Example/rokt.xcodeproj -scheme rokt-Example-AUTOMATION \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest'
```

That scheme is deliberately separate from `rokt-Example-MOCK`, which is what CI runs — adding a
UI-test bundle there would change CI with no workflow edit. Wiring this into CI is a follow-up.
