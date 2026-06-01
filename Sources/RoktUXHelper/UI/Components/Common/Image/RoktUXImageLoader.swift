import SwiftUI

/// A type for loading images from a URL.
/// The RoktLayoutView accepts an optional ImageLoader to give partners flexibility over image downloads.
public protocol RoktUXImageLoader: AnyObject {
    /// Loads an image from the specified URL string.
    /// - Parameters:
    ///   - urlString: The URL string of the image to be loaded.
    ///   - completion: A completion handler that is called with the result of the image loading operation. It returns either the loaded UIImage or an Error.
    func loadImage(urlString: String,
                   completion: @escaping (Result<UIImage?, Error>) -> Void)
}
