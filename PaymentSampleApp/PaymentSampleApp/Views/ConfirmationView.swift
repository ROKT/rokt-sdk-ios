import SwiftUI

struct ConfirmationView: View {
    @Environment(SDKState.self) private var sdkState
    @State private var showCheckmark = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
                .scaleEffect(showCheckmark ? 1.0 : 0.3)
                .opacity(showCheckmark ? 1.0 : 0.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCheckmark)

            Text("Order Confirmed!")
                .font(.title.bold())
                .opacity(showCheckmark ? 1.0 : 0.0)
                .animation(.easeIn(duration: 0.3).delay(0.2), value: showCheckmark)

            VStack(spacing: 12) {
                Text("Thank you for your purchase")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Order #\(Int.random(in: 100000...999999))")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
            .opacity(showCheckmark ? 1.0 : 0.0)
            .animation(.easeIn(duration: 0.3).delay(0.4), value: showCheckmark)

            Spacer()

            recentEventsSection
        }
        .padding()
        .navigationTitle("Confirmation")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .onAppear {
            showCheckmark = true
            sdkState.log("Confirmation screen shown")
        }
    }

    @ViewBuilder
    private var recentEventsSection: some View {
        if !sdkState.eventLog.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent Events")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                ForEach(sdkState.eventLog.prefix(5)) { entry in
                    Text(entry.message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
