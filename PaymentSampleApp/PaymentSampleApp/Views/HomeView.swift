import SwiftUI
import Rokt_Widget

struct HomeView: View {
    @Environment(SDKState.self) private var sdkState

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "cart.fill.badge.plus")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                Text("Shoppable Ads")
                    .font(.largeTitle.bold())

                Text("Post Purchase Upsell Demo")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                sdkStatusView

                Spacer()

                NavigationLink {
                    CheckoutView()
                } label: {
                    Label("Start Checkout", systemImage: "bag")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(sdkState.isInitialized ? Color.blue : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!sdkState.isInitialized)

                NavigationLink {
                    EventLogView()
                } label: {
                    Label("Event Log", systemImage: "list.bullet.rectangle")
                        .font(.subheadline)
                }
            }
            .padding()
            .navigationTitle("Payment Sample")
        }
    }

    @ViewBuilder
    private var sdkStatusView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: sdkState.isInitialized ? "checkmark.circle.fill" : "clock")
                    .foregroundStyle(sdkState.isInitialized ? .green : .orange)
                Text("SDK Initialized")
                    .font(.footnote)
                Spacer()
                Text(sdkState.isInitialized ? "Ready" : "Initializing...")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Image(systemName: sdkState.paymentExtensionRegistered ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(sdkState.paymentExtensionRegistered ? .green : .secondary)
                Text("Payment Extension")
                    .font(.footnote)
                Spacer()
                Text(sdkState.paymentExtensionRegistered ? "Registered" : "Not registered")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
