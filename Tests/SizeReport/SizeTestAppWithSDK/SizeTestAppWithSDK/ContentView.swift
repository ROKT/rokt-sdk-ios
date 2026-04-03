import SwiftUI
import Rokt_Widget

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Rokt SDK Size Test")
                .font(.headline)
            Text("This app includes the Rokt SDK for size measurement.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding()
        }
        .padding()
        .onAppear {
            showPlacement()
        }
    }

    func showPlacement() {
        // Execute Rokt SDK with test attributes
        // Reference: https://docs.rokt.com/developers/integration-guides/ios/how-to/adding-a-placement
        let attributes = [
            "email": "j.smith@rokt.com",
            "firstname": "Jenny",
            "lastname": "Smith",
            "mobile": "(555)867-5309",
            "postcode": "90210",
            "country": "US"
        ]

        Rokt.selectPlacements(
            identifier: "RoktExperience",
            attributes: attributes,
            onEvent: { roktEvent in
                print("Rokt event: \(roktEvent)")
            }
        )
    }
}

#Preview {
    ContentView()
}
