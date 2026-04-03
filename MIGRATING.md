# Migration Guide

This document provides guidance on migrating to newer versions of the Rokt iOS SDK.

## Migrating from versions < 5.0.0

### Installation Changes

#### Swift Package Manager

The Rokt iOS SDK has moved from a **binary XCFramework** distribution to **source distribution** as of v5.0.0. The package URL remains the same, but you must update the version.

Update your SPM dependency to `5.0.0` or later:

```swift
// Package.swift
.package(url: "https://github.com/ROKT/rokt-sdk-ios", from: "5.0.0")
```

Or in Xcode: **File → Add Package Dependencies**, enter the URL, and select version `5.0.0` or later.

#### CocoaPods

CocoaPods distributions have also moved to source. Update your `Podfile`:

```ruby
pod 'Rokt-Widget', '~> 5.0'
```

Then run:

```sh
pod install
```

> **Note:** If you were previously using a pre-built XCFramework, you may need to remove the old framework reference from your Xcode project before reinstalling.

---

### Minimum iOS Version Bumped to iOS 15

The minimum supported iOS version has been raised from iOS 12 to iOS 15. If your app still supports iOS 13 or iOS 14, you will need to conditionally gate Rokt SDK usage or raise your own deployment target.

Update your deployment target in Xcode under **Build Settings → iOS Deployment Target → iOS 15.0**.

As a consequence, all `@available(iOS 15, *)` guards have been removed from the SDK's public API — every method is now available unconditionally on iOS 15+.

---

### API Method Changes

#### `execute()` / `execute2step()` / `executeWithEvents()` → `selectPlacements()`

The primary execution methods have been consolidated into `selectPlacements()`.

- Parameter `viewName` has been renamed to `identifier`
- Multiple callback parameters (`onLoad`, `onUnLoad`, `onShouldShowLoadingIndicator`, `onShouldHideLoadingIndicator`, `onEmbeddedSizeChange`) have been replaced with a single `onEvent` callback that receives `RoktEvent` objects

**Before:**

```swift
let placements = ["Location1": location1EmbeddedView]

Rokt.execute(
    viewName: "checkout",
    attributes: ["email": "user@example.com"],
    placements: placements,
    onLoad: {
        spinner.stopAnimating()
    },
    onUnLoad: {
        // cleanup
    },
    onShouldShowLoadingIndicator: {
        spinner.startAnimating()
    },
    onShouldHideLoadingIndicator: {
        spinner.stopAnimating()
    },
    onEmbeddedSizeChange: { placementName, height in
        self.updatePlacementHeight(placementName, height: height)
    }
)
```

**After:**

```swift
let placements = ["Location1": location1EmbeddedView]

Rokt.selectPlacements(
    identifier: "checkout",
    attributes: ["email": "user@example.com"],
    placements: placements,
    onEvent: { event in
        if let sizeEvent = event as? RoktEvent.EmbeddedSizeChanged {
            self.updatePlacementHeight(sizeEvent.identifier, height: sizeEvent.updatedHeight)
        } else if event is RoktEvent.ShowLoadingIndicator {
            spinner.startAnimating()
        } else if event is RoktEvent.HideLoadingIndicator {
            spinner.stopAnimating()
        }
    }
)
```

---

#### `RoktLayout` Parameter Changes (SwiftUI)

- Parameter `viewName` has been renamed to `identifier`
- Parameter `locationName` has been renamed to `location`
- `identifier` is now **required** (no longer optional)
- `attributes` now defaults to `[:]` (empty dictionary)

**Before:**

```swift
RoktLayout(
    sdkTriggered: $sdkTriggered,
    viewName: "checkout",
    locationName: "Location1",
    identifier: nil,
    attributes: attributes
)
```

**After:**

```swift
RoktLayout(
    sdkTriggered: $sdkTriggered,
    identifier: "checkout",
    location: "Location1",
    attributes: attributes
)
```

---

#### `purchaseFinalized()` Parameter Rename

Parameter `placementId` has been renamed to `identifier`. The `@available(iOS 15.0, *)` requirement has also been removed.

**Before:**

```swift
Rokt.purchaseFinalized(placementId: "checkout", catalogItemId: "item-123", success: true)
```

**After:**

```swift
Rokt.purchaseFinalized(identifier: "checkout", catalogItemId: "item-123", success: true)
```

---

#### `events()` Parameter Rename

Parameter `viewName` has been renamed to `identifier`.

**Before:**

```swift
Rokt.events(viewName: "checkout") { event in
    print("Received event: \(event)")
}
```

**After:**

```swift
Rokt.events(identifier: "checkout") { event in
    print("Received event: \(event)")
}
```

---

#### `PlacementOptions` Renamed to `RoktPlacementOptions`

If you were passing placement timing data from a joint SDK integration, the type has been renamed.

**Before:**

```swift
Rokt.selectPlacements(
    identifier: "checkout",
    attributes: attributes,
    placementOptions: PlacementOptions(...)
)
```

**After:**

```swift
Rokt.selectPlacements(
    identifier: "checkout",
    attributes: attributes,
    placementOptions: RoktPlacementOptions(...)
)
```

---

### Initialization Changes

#### `initWith()` Callbacks Removed

The `onInitComplete` callback parameter has been removed from both the standard and mParticle `initWith()` methods. Use `globalEvents()` to listen for initialization completion events instead.

**Before:**

```swift
Rokt.initWith(roktTagId: "your-tag-id") { success in
    if success {
        print("Rokt initialized successfully")
    }
}
```

**After:**

```swift
Rokt.globalEvents { event in
    if let initEvent = event as? RoktEvent.InitComplete {
        if initEvent.success {
            print("Rokt initialized successfully")
        }
    }
}

Rokt.initWith(roktTagId: "your-tag-id")
```

> **Important:** Register `globalEvents` **before** calling `initWith` to ensure you don't miss the `InitComplete` event.

---

### Removed Methods

#### `setLoggingEnabled()`

This method has been removed. Use `Rokt.setLogLevel(_:)` for granular control over logging output.

**Before:**

```swift
Rokt.setLoggingEnabled(enable: true)
```

**After:**

```swift
Rokt.setLogLevel(.debug)    // verbose logging
// or
Rokt.setLogLevel(.error)    // errors only
// or
Rokt.setLogLevel(.none)     // no logging (default in production)
```

---

### Example Migration

**Before (typical v4 integration):**

```swift
// AppDelegate.swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions ...) -> Bool {
    Rokt.initWith(roktTagId: "your-tag-id") { success in
        print("Rokt init: \(success)")
    }
    Rokt.setLoggingEnabled(enable: true)
    return true
}

// OrderConfirmationViewController.swift
func viewDidLoad() {
    super.viewDidLoad()
    let placements = ["Location1": embeddedView]
    Rokt.execute(
        viewName: "checkout",
        attributes: ["email": email],
        placements: placements,
        onLoad: { self.spinner.stopAnimating() },
        onShouldShowLoadingIndicator: { self.spinner.startAnimating() },
        onShouldHideLoadingIndicator: { self.spinner.stopAnimating() },
        onEmbeddedSizeChange: { placement, height in
            self.embeddedViewHeight.constant = height
        }
    )
}
```

**After (v5):**

```swift
// AppDelegate.swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions ...) -> Bool {
    Rokt.globalEvents { event in
        if let initEvent = event as? RoktEvent.InitComplete {
            print("Rokt init: \(initEvent.success)")
        }
    }
    Rokt.initWith(roktTagId: "your-tag-id")
    Rokt.setLogLevel(.debug)
    return true
}

// OrderConfirmationViewController.swift
func viewDidLoad() {
    super.viewDidLoad()
    let placements = ["Location1": embeddedView]
    Rokt.selectPlacements(
        identifier: "checkout",
        attributes: ["email": email],
        placements: placements,
        onEvent: { event in
            if let sizeEvent = event as? RoktEvent.EmbeddedSizeChanged {
                self.embeddedViewHeight.constant = sizeEvent.updatedHeight
            } else if event is RoktEvent.ShowLoadingIndicator {
                self.spinner.startAnimating()
            } else if event is RoktEvent.HideLoadingIndicator {
                self.spinner.stopAnimating()
            }
        }
    )
}
```

---

## Migrating from versions < 4.8.x

Migration steps were not provided prior to version 4.8.x. If you're upgrading from an older version it's recommended you follow the [initial integration steps](https://docs.rokt.com/developers/integration-guides/ios/how-to/integrating-and-initializing).
