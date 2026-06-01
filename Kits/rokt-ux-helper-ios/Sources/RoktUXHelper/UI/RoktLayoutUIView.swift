import UIKit
import SwiftUI

/// A UIView class for loading and displaying Rokt UX layouts.
/// The RoktLayoutUIView class provides multiple initialization options,
/// allowing for configuration flexibility. You can initialize it with an experienceResponse
/// and optional configuration parameters such as RoktUXConfig, RoktUXImageLoader, and event handlers.
@objc public class RoktLayoutUIView: UIView {
    private(set) var roktEmbeddedSwiftUIView: UIView?
    private var uxHelper: RoktUX?
    private var experienceResponse: String?
    private var location: String?
    private var config: RoktUXConfig?
    private var onUXEvent: ((RoktUXEvent) -> Void)?
    private var onPlatformEvent: (([String: Any]) -> Void)?
    private var onEmbeddedSizeChange: ((CGFloat) -> Void)?
    private var hasLoadedLayout = false
    private lazy var heightConstraint: NSLayoutConstraint = .init(item: self,
                                                                  attribute: .height,
                                                                  relatedBy: .equal,
                                                                  toItem: nil,
                                                                  attribute: .notAnAttribute,
                                                                  multiplier: 1,
                                                                  constant: 0)

    public override init(frame: CGRect) {
        super.init(frame: frame)
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    /// Initializes a new instance with the specified parameters.
    /// - Parameters:
    ///   - experienceResponse: The response string from the experience.
    ///   - location: The name of the layout element selector.
    ///   - config: Configuration for Rokt UX.
    ///   - onUXEvent: Closure to handle UX events.
    ///   - onPlatformEvent: Closure to handle platform events.
    ///   - onEmbeddedSizeChange: Closure to handle changes in embedded layout size.
    public init(experienceResponse: String,
                location: String,
                config: RoktUXConfig? = nil,
                onUXEvent: ((RoktUXEvent) -> Void)?,
                onPlatformEvent: (([String: Any]) -> Void)?,
                onEmbeddedSizeChange: ((CGFloat) -> Void)? = nil) {
        self.location = location
        self.experienceResponse = experienceResponse
        self.config = config
        self.onUXEvent = onUXEvent
        self.onPlatformEvent = onPlatformEvent
        self.onEmbeddedSizeChange = onEmbeddedSizeChange
        super.init(frame: .zero)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        if let experienceResponse, !hasLoadedLayout {
            hasLoadedLayout = true
            loadLayout(
                experienceResponse: experienceResponse,
                location: location,
                config: config,
                onUXEvent: onUXEvent,
                onPlatformEvent: onPlatformEvent,
                onEmbeddedSizeChange: onEmbeddedSizeChange
            )
        }
    }

    /// Loads the layout with the specified parameters.
    /// - Parameters:
    ///   - experienceResponse: The response string from the experience.
    ///   - location: The name of the layout element selector.
    ///   - config: Configuration for Rokt UX.
    ///   - onUXEvent: Closure to handle UX events.
    ///   - onPlatformEvent: Closure to handle platform events.
    ///   - onEmbeddedSizeChange: Closure to handle changes in embedded layout size.
    public func loadLayout(experienceResponse: String,
                           location: String?,
                           config: RoktUXConfig? = nil,
                           onUXEvent: ((RoktUXEvent) -> Void)?,
                           onPlatformEvent: (([String: Any]) -> Void)?,
                           onEmbeddedSizeChange: ((CGFloat) -> Void)? = nil) {
        self.onEmbeddedSizeChange = onEmbeddedSizeChange
        uxHelper = RoktUX()
        uxHelper?.loadLayout(
            experienceResponse: experienceResponse,
            layoutLoaders: [location ?? "": self],
            config: config,
            onRoktUXEvent: { event in onUXEvent?(event) },
            onRoktPlatformEvent: { platformEvent in onPlatformEvent?(platformEvent) },
            onEmbeddedSizeChange: { [weak self] location, size in
                if location == self?.location {
                    onEmbeddedSizeChange?(size)
                }
            }
        )
    }

    /// Call when device pay has succeeded or failed.
    /// - Parameters:
    ///   - layoutId: layout Id for the relevant displayed catalog item.
    ///   - catalogItemId: Id of the catalog item that was selected.
    ///   - success: whether the purchase succeeded or failed.
    public func devicePayFinalized(layoutId: String, catalogItemId: String, success: Bool) {
        uxHelper?.devicePayFinalized(layoutId: layoutId, catalogItemId: catalogItemId, success: success)
    }

    /// Call after the host SDK has fetched the runtime catalog data (e.g. an order breakdown
    /// from `/v1/cart/initialize-purchase`) to display the confirmation screen.
    /// - Parameters:
    ///   - layoutId: layout Id for the relevant displayed catalog item.
    ///   - catalogItemId: Id of the catalog item that was selected.
    ///   - catalogRuntimeData: dictionary of pre-formatted runtime values keyed to match
    ///     `%^DATA.catalogRuntime.<key>^%` placeholders in the layout — typically the order
    ///     breakdown (e.g. `["subtotal": "$24.00", "tax": "$1.94", "shipping": "$0.00", "total": "$26.72"]`).
    public func devicePayShowConfirmation(
        layoutId: String,
        catalogItemId: String,
        catalogRuntimeData: [String: String]
    ) {
        uxHelper?.devicePayShowConfirmation(
            layoutId: layoutId,
            catalogItemId: catalogItemId,
            catalogRuntimeData: catalogRuntimeData
        )
    }

    /// Call when a forward-payment flow has succeeded or failed.
    /// - Parameters:
    ///   - layoutId: layout Id for the relevant displayed catalog item.
    ///   - catalogItemId: Id of the catalog item that was selected.
    ///   - success: whether the payment succeeded or failed.
    ///   - failureReason: optional reason emitted on failure.
    public func forwardPaymentFinalized(
        layoutId: String,
        catalogItemId: String,
        success: Bool,
        failureReason: String? = nil
    ) {
        uxHelper?.forwardPaymentFinalized(
            layoutId: layoutId,
            catalogItemId: catalogItemId,
            success: success,
            failureReason: failureReason
        )
    }

    private func addEmbeddedLayoutConstraints(embeddedView: UIView) {
        NSLayoutConstraint.activate([
            embeddedView.topAnchor.constraint(equalTo: topAnchor),
            embeddedView.leadingAnchor.constraint(equalTo: leadingAnchor),
            embeddedView.trailingAnchor.constraint(equalTo: trailingAnchor),
            embeddedView.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightConstraint
        ])
    }
}

extension RoktLayoutUIView: LayoutLoader {

    /// Loads the layout content with the specified parameters.
    /// - Parameters:
    ///   - onSizeChanged: Closure to handle size changes.
    ///   - injectedView: A closure returning the SwiftUI view to embed.
    public func load<Content>(onSizeChanged: @escaping ((CGFloat) -> Void),
                              injectedView: @escaping () -> Content) where Content: View {
        roktEmbeddedSwiftUIView?.removeFromSuperview()
        let vc = ResizableHostingController(rootView: AnyView(injectedView()))
        guard let swiftUIView = vc.view else { return }

        self.roktEmbeddedSwiftUIView = swiftUIView
        parentViewControllers?.addChild(vc)
        swiftUIView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(swiftUIView)
        addEmbeddedLayoutConstraints(embeddedView: swiftUIView)
        vc.didMove(toParent: parentViewControllers)
        RoktUXLogger.shared.debug("Embedded view attached to the screen")
    }

    /// Updates the size of the embedded view.
    /// - Parameter size: The new height for the embedded view.
    public func updateEmbeddedSize(_ size: CGFloat) {
        if roktEmbeddedSwiftUIView != nil {
            heightConstraint.constant = size
            RoktUXLogger.shared.debug("Embedded height resized to \(size)")
        }
    }

    /// Closes the embedded view and notifies the size change.
    public func closeEmbedded() {
        // change the size to zero
        updateEmbeddedSize(0)
        // remove view from superView
        roktEmbeddedSwiftUIView?.removeFromSuperview()
        roktEmbeddedSwiftUIView = nil
        // notify the changes
        onEmbeddedSizeChange?(0)
        RoktUXLogger.shared.debug("User journey ended on Embedded view")
    }
}
