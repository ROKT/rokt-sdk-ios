import SwiftUI
internal import RoktUXHelper

public struct RoktLayout: View {
    @Binding var sdkTriggered: Bool
    @StateObject private var viewModel: RoktLayoutViewModel

    public init(
        sdkTriggered: Binding<Bool>,
        identifier: String,
        location: String = "",
        attributes: [String: String] = [:],
        config: RoktConfig? = nil,
        placementOptions: PlacementOptions? = nil,
    ) {
        _sdkTriggered = sdkTriggered
        self._viewModel = .init(
            wrappedValue: .init(
                identifier: identifier,
                location: location,
                attributes: attributes,
                config: config,
                placementOptions: placementOptions,
                onRoktEvent: nil
            )
        )
    }

    public init(
        sdkTriggered: Binding<Bool>,
        identifier: String,
        location: String = "",
        attributes: [String: String] = [:],
        config: RoktConfig? = nil,
        placementOptions: PlacementOptions? = nil,
        onEvent: ((RoktEvent) -> Void)? = nil
    ) {
        _sdkTriggered = sdkTriggered
        self._viewModel = .init(
            wrappedValue: .init(
                identifier: identifier,
                location: location,
                attributes: attributes,
                config: config,
                placementOptions: placementOptions,
                onRoktEvent: onEvent
            )
        )
    }

    public var body: some View {
        VStack {
            switch viewModel.state {
            case .ready(let anyView):
                anyView
            case .empty:
                EmptyView()
            }
        }
        .onAppear {
            if sdkTriggered {
                viewModel.execute()
            }
        }
        .onChange(of: sdkTriggered) { isTriggered in
            if isTriggered {
                viewModel.execute()
            }
        }
    }
}
