import SwiftUI

/// A SwiftUI view for loading and displaying Rokt UX layouts.
/// The RoktLayoutView class provides multiple initialization options, allowing for configuration flexibility.
/// You can initialize it by passing required bindings and parameters like experienceResponse, optional config, ImageLoader, and event handlers.
@available(iOS 15, *)
public struct RoktLayoutView: View {
    @StateObject private var viewModel: RoktLayoutViewModel

    /// Initializes a new instance with the specified parameters.
    /// - Parameters:
    ///   - experienceResponse: The response string from the experience.
    ///   - location: The name of the layout element selector.
    ///   - config: Configuration for Rokt UX.
    ///   - onUXEvent: Closure to handle UX events.
    ///   - onPlatformEvent: Closure to handle platform events.
    public init(experienceResponse: String,
                location: String,
                config: RoktUXConfig? = nil,
                onUXEvent: ((RoktUXEvent) -> Void)?,
                onPlatformEvent: (([String: Any]) -> Void)?) {
        self._viewModel = .init(
            wrappedValue: RoktLayoutViewModel(
                experienceResponse: experienceResponse,
                location: location,
                config: config,
                onUXEvent: onUXEvent,
                onPlatformEvent: onPlatformEvent
            )
        )
    }

    public var body: some View {
        VStack {
            switch viewModel.state {
            case let .ready(view):
                view
                    .frame(height: viewModel.height)
                    .frame(maxWidth: .infinity)
            case .empty:
                EmptyView()
            }
        }
        .onAppear {
            viewModel.loadLayout()
        }
    }
}
