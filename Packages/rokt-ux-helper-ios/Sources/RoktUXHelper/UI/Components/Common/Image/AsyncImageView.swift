import SwiftUI
import Combine
import DcuiSchema

@available(iOS 15, *)
struct AsyncImageView: View {
    @SwiftUI.Environment(\.colorScheme) var colorScheme

    let imageUrl: ThemeUrl?
    let scale: BackgroundImageScale?
    var alt: String?
    var imageLoader: RoktUXImageLoader?

    private var altString: String {
        alt ?? ""
    }

    private var imgURL: String {
        switch colorScheme {
        case .dark:
            imageUrl?.dark ?? ""
        default:
            imageUrl?.light ?? ""
        }
    }

    var stringBase64: String {
        // we will remove the data URI scheme, data:content/type;base64,
        guard let dataImagePrefix = imgURL.range(of: "data:image/"),
              let base64Suffix = imgURL.range(of: ";base64,")
        else { return imgURL }

        let uriSchemeRange = dataImagePrefix.lowerBound..<base64Suffix.upperBound
        let uriScheme = imgURL[uriSchemeRange]

        return imgURL.replacingOccurrences(of: uriScheme, with: "")
    }

    var isURLBase64Image: Bool {
        imgURL.contains("data:image/") && imgURL.contains(";base64")
    }

    @Binding var isImageValid: Bool

    var body: some View {
        if imageUrl != nil {
            if isURLBase64Image,
               let base64Data = Data(base64Encoded: stringBase64),
               let base64Image = UIImage(data: base64Data) {
                Base64Image(scale: scale,
                            altString: altString,
                            base64Image: base64Image)
            } else if let imageLoader {
                ExternalAsyncImage(urlString: imgURL,
                                   scale: scale,
                                   altString: altString,
                                   loader: imageLoader)
            } else {
                AsyncImage(url: URL(string: imgURL)) { phase in
                    if let image = phase.image { // valid
                        image.scaleIfNeeded(scale: scale)
                    } else if phase.error != nil { // error
                        let _ = setImageAsInvalid() // swiftlint:disable:this redundant_discardable_let
                        EmptyView()
                    } else { // placeholder
                        EmptyView()
                    }
                }
                .accessibilityLabel(altString)
                .accessibilityHidden(altString.isEmpty)
            }
        } else {
            EmptyView()
        }
    }

    func setImageAsInvalid() {
        DispatchQueue.main.async {
            isImageValid = false
        }
    }
}
