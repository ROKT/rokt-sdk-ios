import SwiftUI
import Combine
import DcuiSchema

@available(iOS 15, *)
struct Base64Image: View {
    let scale: BackgroundImageScale?
    let altString: String
    let base64Image: UIImage

    var body: some View {
        Image(uiImage: base64Image)
            .scaleIfNeeded(scale: scale)
            .accessibilityLabel(altString)
            .accessibilityHidden(altString.isEmpty)
    }
}
