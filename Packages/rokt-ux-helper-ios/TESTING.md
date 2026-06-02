# Testing Guide

## Snapshot Testing

### Overview

Snapshot tests render SwiftUI components into images and compare them pixel-by-pixel against committed reference PNGs. They catch visual regressions that unit assertions would miss (e.g. font-stripping, missing underline, broken layout).

The library used is [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) by Point-Free.

### Shared Configuration

All snapshot tests use a shared device config defined in:

```text
Tests/RoktUXHelperTests/UI/Utils/SnapshotConfig.swift
```

This ensures every snapshot renders against the same viewport (`iPhone13Pro`, portrait). To change the target device, update `snapshotDevice` in that file and re-record all reference images.

### Reference Image Location

Reference PNGs are stored next to the test file in a `__Snapshots__/` directory, named after the test class and method:

```text
Tests/RoktUXHelperTests/UI/Components/__Snapshots__/
  TestBasicTextComponent/testSnapshot.1.png
  TestCatalogImageGalleryComponent/testSnapshot_fullFeatured.1.png
  TestColumnComponent/testSnapshot.1.png
  TestCreativeResponseComponent/testSnapshot.1.png
  TestRichTextComponent/testSnapshot.1.png
  TestRichTextComponent/testSnapshot_nilDefaultStyle.1.png
  TestRichTextComponent/testSnapshot_nilTextStyle.1.png
  TestRowComponent/testSnapshot_withChildren.1.png
  TestRuntimeAndTransactionDataPlaceholders/testSnapshot_basicText_catalogRuntimeFallsBackToDefault_whenDataMissing.1.png
  TestRuntimeAndTransactionDataPlaceholders/testSnapshot_basicText_mandatoryOrphan_zeroesLine.1.png
  TestRuntimeAndTransactionDataPlaceholders/testSnapshot_basicText_optionalOrphan_substitutesDefault.1.png
  TestRuntimeAndTransactionDataPlaceholders/testSnapshot_basicText_resolvesCatalogRuntimePlaceholders.1.png
  TestRuntimeAndTransactionDataPlaceholders/testSnapshot_basicText_resolvesShippingAddressFromTransactionData.1.png
  TestScrollableColumn/testSnapshot.1.png
  TestToggleButtonComponent/testSnapshot.1.png
  TestZStackComponent/testSnapshot.1.png
```

These PNGs **must** be committed to the repository. If they are missing, the test records a new image and fails on the first run.

### Test Fixture Location

JSON fixtures used by component tests live under `Tests/RoktUXHelperTests/Supporting Files/`. Note that the subdirectory names don't always match the component -- for example, `Supporting Files/ZStack/` contains fixtures for ZStack, ToggleButton, and other components that share the same directory. Check `ModelTestData.swift` to see which JSON file maps to which component model.

### Adding a New Snapshot Test

1. **Create the test method** in the appropriate `Test*Component.swift` file. Use `snapshotDevice` for the device config:

```swift
/// Brief description of what this snapshot validates.
func testSnapshot_myNewCase() {
    let view = TestPlaceHolder(layout: LayoutSchemaViewModel.richText(model))
        .frame(width: 350, height: 200)

    let hostingController = UIHostingController(rootView: view)
    assertSnapshot(of: hostingController, as: .image(on: snapshotDevice))
}
```

2. **Run the test** locally (Cmd+U or right-click the test). It will fail and record a new reference image.

3. **Inspect the generated PNG** in `__Snapshots__/` to verify it looks correct.

4. **Run the test again** to confirm it passes against the new reference.

5. **Commit the reference PNG** alongside your test code.

### Updating Snapshots After an Intentional UI Change

If you change component styling, layout, or rendering logic, existing snapshot tests **will fail** -- this is expected and means the tests are doing their job. Here is how to update them:

#### Option A: Delete and re-record (recommended for a few snapshots)

1. **Run the tests** (Cmd+U). Note which snapshot tests fail.
2. **Delete the old reference PNGs** for the failing tests from `__Snapshots__/`. For example:

```bash
rm Tests/RoktUXHelperTests/UI/Components/__Snapshots__/TestRichTextComponent/testSnapshot.1.png
```

3. **Run the tests again.** The library records new reference images and the tests fail once more (first-run recording).
4. **Inspect each new PNG** in `__Snapshots__/` to confirm it reflects your intended change.
5. **Run the tests a third time.** They should now pass.
6. **Commit the updated PNGs** alongside your code changes in the same PR.

#### Option B: Use `isRecording` flag (recommended for bulk updates)

When many snapshots need re-recording at once (e.g. changing the shared device config or a global style):

1. **Set the global recording flag** at the top of the test file or in `setUp()`:

```swift
override func setUp() {
    super.setUp()
    isRecording = true
}
```

2. **Run all snapshot tests** (Cmd+U). Every snapshot is re-recorded and the tests fail.
3. **Remove `isRecording = true`** -- do not commit it.
4. **Run the tests again** to confirm they pass with the new references.
5. **Review the git diff** of the changed PNGs to verify the visual changes are intentional.
6. **Commit the updated PNGs** alongside your code changes.

> **Important:** Never commit `isRecording = true`. It disables regression detection. PR reviewers should flag this if spotted.

#### Checklist for PR authors

- [ ] All snapshot tests pass locally after re-recording
- [ ] Updated reference PNGs are committed in the PR
- [ ] `isRecording = true` is **not** present in committed code
- [ ] New PNGs have been visually inspected

### Debugging CI Failures

When snapshot tests fail in CI:

1. Go to the failed GitHub Actions run.
2. Download the **snapshot-failures** artifact (uploaded automatically on test failure).
3. The artifact contains the actual rendered image and a diff highlighting pixel differences.
4. Compare against the committed reference to determine if the change is intentional or a regression.
5. If intentional, follow the update process above and push updated reference PNGs. If unexpected, investigate the code change that caused the diff.

### Environment Sensitivity

Snapshot images are sensitive to the OS version and simulator device. The CI uses:

- **Xcode**: 16.4
- **Simulator**: iPhone 16, iOS >= 18.0
- **Viewport**: Set by `snapshotDevice` (currently `ViewImageConfig.iPhone13Pro(.portrait)`)

The `ViewImageConfig` sets the rendering viewport explicitly, so the simulator model doesn't affect output. However, font rendering can vary across OS versions. If you see unexpected diffs, ensure your local Xcode and simulator match CI.

### Async Considerations

RichText snapshot tests require waiting for HTML-to-attributed-string conversion, which runs on `DispatchQueue.main.async`. Use the `waitForAttributedStringConversion` helper:

```swift
model.transformValueToAttributedString(.light)
waitForAttributedStringConversion(on: model, timeout: 2.0)
```

This spins the main run loop until `model.attributedString.string` is non-empty or the timeout expires.

### Image Components and Data URIs

Components that load images asynchronously (e.g. `AsyncImageView`) will render blank in snapshot tests when given remote URLs, because network requests don't complete during the synchronous snapshot capture.

To work around this, use **base64 data URIs** for image sources in snapshot factories. `AsyncImageView` already supports `data:image/...;base64,...` URIs and renders them synchronously via `Base64Image`. See `TestCatalogImageGalleryComponent.swift` for an example that defines small solid-color PNGs and arrow icons as static data URI constants.

**ARGB hex format:** The `UIColor(hexString:)` initializer uses **ARGB** byte order for 8-character hex values, not RGBA. For example, 60% opaque black is `#99000000` (not `#00000099`, which would be fully transparent).

### Snapshot Coverage Matrix

This matrix tracks which visual scenarios have snapshot tests and which are known gaps. When adding a new feature or fixing a visual bug, check the relevant component below and add a snapshot for unchecked items where appropriate.

#### BasicText

- [x] Standard rendering -- font, text color, background, fixed height (`testSnapshot`)
- [ ] Dark mode color adaptation
- [ ] Text truncation with `lineLimit`
- [ ] Min/max width constraints

#### Column

- [x] Standard rendering -- background color, centered child (`testSnapshot`)
- [ ] Dark mode color adaptation
- [ ] Border styling
- [ ] Nested columns

#### RichText

- [x] Standard rendering -- bold, italic, underline, strikethrough with campaign font (`testSnapshot`)
- [x] nil `defaultStyle` -- HTML parsed correctly without styling, PR #220 fix (`testSnapshot_nilDefaultStyle`)
- [x] nil text style -- style exists but no text properties, font-stripping guard (`testSnapshot_nilTextStyle`)
- [ ] Link rendering with default blue underline
- [ ] Custom link styling (campaign-configured colors/weight)
- [ ] Dark mode with adapted text/link colors
- [ ] Mixed HTML tags with `<br>` line breaks
- [ ] Plain text with no HTML tags

#### Row

- [x] Multiple children -- BasicText, RichText, CloseButton in a single row (`testSnapshot_withChildren`)

#### ZStack

- [x] Standard rendering -- pink background, padding, centered alignment (`testSnapshot`)
- [ ] Multiple overlapping children

#### OneByOne (Distribution)

- [ ] Embedded one-by-one layout (test exists but is commented out -- see `TestRuntimeAndTransactionDataPlaceholders` for a working `perceptualPrecision: 0.98` pattern that may unblock this)

#### ScrollableColumn

- [x] Standard rendering -- Column with pink background inside a ScrollView (`testSnapshot`)
- [ ] Max height constraint variant
- [ ] Scroll indicator visibility

#### ScrollableRow

- [ ] Standard rendering
- [ ] Scroll indicator visibility

#### Overlay

- [ ] Overlay positioning and backdrop

#### CreativeResponse

- [x] Positive response button -- black background, 10px padding (`testSnapshot`)
- [ ] Negative response button
- [ ] Pressed/hover state

#### ToggleButton

- [x] Default state -- blue background with "Subscribe" label (`testSnapshot`)
- [ ] Selected/toggled state

#### CloseButton

- [ ] Default close button rendering

#### StaticImage / DataImage

- [ ] Image rendering with sizing constraints

#### CatalogImageGallery

- [x] Full-featured rendering -- gallery image, navigation buttons, pill indicator with dots (`testSnapshot_fullFeatured`)

#### Placeholder Resolution (Runtime + Transaction Data)

End-to-end coverage for the placeholder namespaces and the finalize step. These
drive `BasicTextViewModel` directly and through the full `LayoutTransformer`
pipeline. They use `perceptualPrecision: 0.98` to tolerate sub-pixel text
rendering drift across simulator runtimes.

- [x] `DATA.catalogRuntime.*` -- host-pushed runtime values resolved reactively from `LayoutState.catalogRuntimeDataKey` (`testSnapshot_basicText_resolvesCatalogRuntimePlaceholders`)
- [x] `DATA.catalogRuntime.*` fallback -- `--` default substitutes when host has not pushed runtime data (`testSnapshot_basicText_catalogRuntimeFallsBackToDefault_whenDataMissing`)
- [x] `DATA.transactionData.shippingAddress.*` -- full transformer pipeline, `TransactionDataMapper` resolves from active offer via `LayoutState.fullOfferKey` (`testSnapshot_basicText_resolvesShippingAddressFromTransactionData`)
- [x] OrphanedPlaceholderResolver -- optional orphan with `|` default substitutes the literal, line stays (`testSnapshot_basicText_optionalOrphan_substitutesDefault`)
- [x] OrphanedPlaceholderResolver -- mandatory orphan (no `|` default) zeroes the line, `boundValue == ""` (`testSnapshot_basicText_mandatoryOrphan_zeroesLine`)

#### ProgressIndicator / ProgressControl

- [ ] Progress bar rendering at various states

> **Contributing:** When you add a new snapshot test, check the box above and note the test method name. When you identify a new scenario worth covering, add an unchecked item.
