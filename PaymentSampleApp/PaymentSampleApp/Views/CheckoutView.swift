import SwiftUI
import Rokt_Widget

struct CheckoutView: View {
    @Environment(SDKState.self) private var sdkState
    @State private var showShoppableAds = false
    @State private var showConfirmation = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false

    private let items = OrderItem.sampleItems

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                orderSummarySection
                shippingSection
                paymentSection
            }
            .padding()
        }
        .navigationTitle("Checkout")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading {
                ProgressView("Loading experience...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("Retry") { triggerShoppableAds() }
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .navigationDestination(isPresented: $showConfirmation) {
            ConfirmationView()
        }
    }

    // MARK: - Order Summary

    @ViewBuilder
    private var orderSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Order Summary", systemImage: "bag")
                .font(.headline)

            ForEach(items) { item in
                HStack {
                    VStack(alignment: .leading) {
                        Text(item.name)
                            .font(.subheadline.bold())
                        Text(item.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(item.formattedTotal)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
            }

            Divider()

            HStack {
                Text("Total")
                    .font(.headline)
                Spacer()
                Text(OrderItem.sampleTotal)
                    .font(.headline)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Shipping

    @ViewBuilder
    private var shippingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Shipping", systemImage: "shippingbox")
                .font(.headline)

            Group {
                Text("Jenny Smith")
                Text("123 Main St, Apt 4B")
                Text("New York, NY 10001")
                Text("United States")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Payment Action

    @ViewBuilder
    private var paymentSection: some View {
        Button {
            triggerShoppableAds()
        } label: {
            HStack {
                Image(systemName: "creditcard")
                Text("Complete Purchase")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Shoppable Ads

    private func triggerShoppableAds() {
        sdkState.log("Triggering shoppableAds()")
        isLoading = true
        errorMessage = nil

        Rokt.shoppableAds(
            viewName: "RoktShoppableAdsDemo",
            attributes: [
                "email": "test@example.com",
                "firstname": "Jenny",
                "lastname": "Smith",
                "billingzipcode": "07762",
                "confirmationref": "ORD-12345",
                "paymenttype": "ApplePay",
                "last4digits": "4444",
                "country": "US",
                "applePayCapabilities": "true",
                "partnerpaymentreference": "ref-sample-001",
                "shippingaddress1": "123 Main St",
                "shippingaddress2": "Apt 4B",
                "shippingcity": "New York",
                "shippingstate": "NY",
                "shippingzipcode": "10001",
                "shippingcountry": "US"
            ],
            onEvent: { event in
                handleEvent(event)
            }
        )
    }

    private func handleEvent(_ event: RoktEvent) {
        switch event {
        case is RoktEvent.ShowLoadingIndicator:
            sdkState.log("ShowLoadingIndicator")
            isLoading = true

        case is RoktEvent.HideLoadingIndicator:
            sdkState.log("HideLoadingIndicator")
            isLoading = false

        case let e as RoktEvent.PlacementReady:
            sdkState.log("PlacementReady: \(e.identifier ?? "nil")")
            isLoading = false

        case let e as RoktEvent.PlacementInteractive:
            sdkState.log("PlacementInteractive: \(e.identifier ?? "nil")")

        case let e as RoktEvent.CartItemInstantPurchase:
            sdkState.log("CartItemInstantPurchase: \(e.catalogItemId) — \(e.totalPrice ?? 0) \(e.currency)")

        case let e as RoktEvent.CartItemInstantPurchaseInitiated:
            sdkState.log("PurchaseInitiated: \(e.catalogItemId)")

        case let e as RoktEvent.CartItemInstantPurchaseFailure:
            sdkState.log("PurchaseFailure: \(e.catalogItemId) — \(e.error ?? "unknown")")

        case let e as RoktEvent.CartItemDevicePay:
            sdkState.log("DevicePay: \(e.catalogItemId) via \(e.paymentProvider)")

        case let e as RoktEvent.InstantPurchaseDismissal:
            sdkState.log("InstantPurchaseDismissal: \(e.identifier)")

        case let e as RoktEvent.PlacementClosed:
            sdkState.log("PlacementClosed: \(e.identifier ?? "nil")")
            isLoading = false
            showConfirmation = true

        case let e as RoktEvent.PlacementCompleted:
            sdkState.log("PlacementCompleted: \(e.identifier ?? "nil")")
            isLoading = false
            showConfirmation = true

        case let e as RoktEvent.PlacementFailure:
            sdkState.log("PlacementFailure: \(e.identifier ?? "nil")")
            isLoading = false
            errorMessage = "Placement could not be displayed. Check that the SDK is initialized and a payment extension is registered."
            showError = true

        default:
            sdkState.log("Event: \(type(of: event))")
        }
    }
}
