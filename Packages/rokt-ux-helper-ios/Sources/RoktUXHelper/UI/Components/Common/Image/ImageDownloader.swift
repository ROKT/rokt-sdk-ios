import Combine
import SwiftUI

@available(iOS 13.0, *)
class ImageDownloader: ObservableObject {
    var imageSubject = CurrentValueSubject<UIImage?, Never>(nil)

    init(urlString: String, loader: RoktUXImageLoader) {
        loader.loadImage(urlString: urlString) { [weak self] result in
            switch result {
            case .success(let image):
                DispatchQueue.main.async {
                    self?.imageSubject.send(image) // Publish the new image
                }
            default:
                break
            }
        }
    }
}
