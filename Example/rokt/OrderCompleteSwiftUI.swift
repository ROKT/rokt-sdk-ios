import SwiftUI
import Rokt_Widget

struct OrderCompleteSwiftUI: View {
    let attributes: [String: String]
    let pageIndentifier: String
    let location: String
    let isEvents: Bool

    let config = RoktConfig.Builder()
        .colorMode(.dark)
        // Mock cache config
        .cacheConfig(RoktConfig.CacheConfig(
            //            cacheDuration: TimeInterval(20),
//            cacheAttributes: ["email": "cache.attributes@rokt.com"]
        ))
        .build()

    @State var sdkTriggered = true

    var body: some View {
        ScrollView(.vertical) {
            Text(location)
                .padding(.leading)
            if isEvents {
                RoktLayout(sdkTriggered: $sdkTriggered,
                           identifier: pageIndentifier,
                           location: location,
                           attributes: attributes) { roktEvent in
                    onRoktEvent(roktEvent: roktEvent)
                }
            } else {
                RoktLayout(
                    sdkTriggered: $sdkTriggered,
                    identifier: pageIndentifier,
                    location: location,
                    attributes: attributes,
                    config: config
                )
            }

            Text("Location2")
                .padding(.leading)

        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func onRoktEvent(roktEvent: RoktEvent) {

        print("Received Rokt event \(roktEvent)")
    }
}

struct OrderCompleteSwiftUI_Previews: PreviewProvider {
    static var previews: some View {
        OrderCompleteSwiftUI(attributes: [:], pageIndentifier: "",
                             location: "Location1",
                             isEvents: true)
    }
}
