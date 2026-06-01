import Foundation
import SwiftUI

/// A type with methods for loading and updating embedded layouts.
@available(iOS 15.0, *)
public protocol LayoutLoader: AnyObject {

    /// Loads the layout content with the specified view.
    /// - Parameters:
    ///   - onSizeChanged: Closure to handle size changes.
    ///   - injectedView: A closure returning the SwiftUI view to embed.
    func load<Content: View>(
        onSizeChanged: @escaping ((CGFloat) -> Void),
        @ViewBuilder injectedView: @escaping () -> Content
    )

    /// Updates the size of the embedded view.
    /// - Parameter size: The new height for the embedded view.
    func updateEmbeddedSize(_ size: CGFloat)

    /// Closes the embedded view.
    func closeEmbedded()
}
