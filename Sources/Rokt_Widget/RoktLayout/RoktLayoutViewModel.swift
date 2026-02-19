import SwiftUI
internal import RoktUXHelper

class RoktLayoutViewModel: ObservableObject {

    enum State {
        case ready(AnyView)
        case empty
    }

    private let identifier: String?
    internal let locationName: String
    private let attributes: [String: String]
    private let config: RoktConfig?
    private let placementOptions: PlacementOptions?
    private let onRoktEvent: ((RoktEvent) -> Void)?
    @Published var state: State = .empty

    init(
        identifier: String?,
        locationName: String,
        attributes: [String: String],
        config: RoktConfig?,
        placementOptions: PlacementOptions?,
        onRoktEvent: ((RoktEvent) -> Void)?
    ) {
        self.identifier = identifier
        self.locationName = locationName
        self.attributes = attributes
        self.config = config
        self.placementOptions = placementOptions
        self.onRoktEvent = onRoktEvent
    }

    func execute() {
        Rokt.shared.roktImplementation.swiftUiExecute(
            viewName: identifier,
            attributes: attributes,
            layout: self,
            config: config,
            placementOptions: placementOptions,
            onRoktEvent: onRoktEvent
        )
    }
}

extension RoktLayoutViewModel: LayoutLoader {
    func load<Content: View>(
        onSizeChanged: @escaping ((CGFloat) -> Void),
        @ViewBuilder injectedView: @escaping () -> Content
    ) {
        state = .ready(AnyView(injectedView()))
    }

    func updateEmbeddedSize(_ size: CGFloat) {}

    func closeEmbedded() {
        state = .empty
    }
}
