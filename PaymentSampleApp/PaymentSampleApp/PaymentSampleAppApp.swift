import SwiftUI
import Rokt_Widget
import RoktStripePaymentExtension

@main
struct PaymentSampleAppApp: App {
    @State private var sdkState = SDKState()

    // Replace with your Stripe test publishable key
    private let stripePublishableKey = "PLACEHOLDER_STRIPE_PUBLISHABLE_KEY"

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(sdkState)
                .task { initializeSDK() }
        }
    }

    private func initializeSDK() {
        Rokt.setLogLevel(.verbose)
        Rokt.setEnvironment(environment: .Stage)
        Rokt.initWith(roktTagId: "PLACEHOLDER_ROKT_TAG_ID")

        // Register Stripe payment extension for Shoppable Ads
        if let ext = RoktStripePaymentExtension(applePayMerchantId: "merchant.rokt.catalog.test") {
            Rokt.registerPaymentExtension(ext, config: [
                "stripeKey": stripePublishableKey
            ])
            sdkState.paymentExtensionRegistered = true
        }

        sdkState.isInitialized = true
    }
}

@Observable
final class SDKState {
    var isInitialized = false
    var paymentExtensionRegistered = false
    var eventLog: [EventLogEntry] = []

    func log(_ message: String) {
        let entry = EventLogEntry(message: message)
        eventLog.insert(entry, at: 0)
        if eventLog.count > 50 { eventLog.removeLast() }
    }
}

struct EventLogEntry: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let message: String
}
