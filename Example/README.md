# iOS Example App

This example demonstrates two ways to integrate RoktUXHelper using `RoktLayoutView` (SwiftUI) and `RoktLayoutUIView` (UIKit) to render a view showcasing multiple offers.

## Prerequisites

- Ensure you have the latest version of Xcode installed.
- clone the repository using `git clone git@github.com:ROKT/rokt-ux-helper-ios.git`
- RoktUXHelper is integrated via Swift Package Manager (SPM). To add the package, simply include the following dependency in your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/ROKT/rokt-ux-helper-ios.git", .upToNextMajor(from: "0.1.0"))
]
```

## SwiftUI Implementation: `RoktLayoutView`

Key parameters:

1. experienceResponse: The layout’s JSON string.
2. location: Name of the element for RoktUX to target the right view.
3. config: Optional, allows us to configure the color mode and handle image downloading (handled by ViewModel in this case).
4. onUXEvent: Callback for real-time user interaction feedback (e.g., opening links).
5. onPlatformEvent: Callback to receive essential integration data to send via your backend.

For detailed documentation, check the [iOS integration guide](https://docs.rokt.com/server-to-server/ios?platform=swiftui).

```swift
var body: some View {
    RoktLayoutView(
        experienceResponse: vm.experienceResponse,
        location: "#target_element", // "targetElementSelector" in experience JSON file
        config: RoktUXConfig.Builder().colorMode(.system).imageLoader(vm).build()
    ) { uxEvent in

        if uxEvent as? RoktUXEvent.LayoutCompleted != nil {
            dismiss()
        } else if let uxEvent = (uxEvent as? RoktUXEvent.OpenUrl) {
            // Handle open URL event
            vm.handleURL(uxEvent)
        }

        // Handle UX events here

    } onPlatformEvent: { platformPayload in
        // Send these platform events to Rokt API
    }.sheet(item: $vm.urlToOpen) {
        SafariWebView(url: $0)
    }
}
```

## UIKit Implementation: `RoktLayoutUIView`

Similar to `RoktLayoutView`, handle the same parameters, add `RoktLayoutUIView` to your view hierarchy and layout your views accordingly.

For more details, refer to the [UIKit integration guide](https://docs.rokt.com/server-to-server/ios?platform=uikit).

```swift
let roktView = RoktLayoutUIView(
    experienceResponse: experience,
    location: "#target_element" // "targetElementSelector" in experience JSON file
) { [weak self] uxEvent in
    guard let self else { return }

    // Handle open URL event
    // Here is a sample how to open different types of URLs
    if let event = uxEvent as? RoktUXEvent.OpenUrl,
       let url = URL(string: event.url){
        switch event.type {
        case .externally:
            UIApplication.shared.open(url) { _ in
                event.onClose?(event.id) // This must be called when the user is ready for the next offer
            }
        default:
            let safariVC = SFSafariViewController(url: url)
            safariVC.modalPresentationStyle = .pageSheet
            present(safariVC, animated: true) {
                event.onClose?(event.id) // This must be called when the user is ready for the next offer
            }
        }
    } else if uxEvent as? RoktUXEvent.LayoutCompleted != nil {
        dismiss(animated: true)
    }

    // Handle UX events here

} onPlatformEvent: { platformEvent in
    // Send these platform events to Rokt API
}

view.addSubview(roktView)

roktView.translatesAutoresizingMaskIntoConstraints = false

NSLayoutConstraint.activate([
    roktView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100),
    roktView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
    roktView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    roktView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor)
])

```
