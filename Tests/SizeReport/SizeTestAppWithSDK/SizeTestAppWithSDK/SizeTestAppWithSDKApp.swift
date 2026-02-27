import SwiftUI
import Rokt_Widget

@main
struct SizeTestAppWithSDKApp: App {
    init() {
        // Initialize the Rokt SDK
        // Reference: https://docs.rokt.com/developers/integration-guides/ios/how-to/integrating-and-initializing
        // Using test Rokt Account ID: 222
        Rokt.initWith(roktTagId: "222")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
