import SwiftUI
import DcuiSchema

@available(iOS 15, *)
struct BackgroundModifier: ViewModifier {
    @SwiftUI.Environment(\.colorScheme) var colorScheme

    let backgroundStyle: BackgroundStylingProperties?
    let imageLoader: RoktUXImageLoader?

    var hasBackgroundColor: Bool {
        guard let backgroundColor = backgroundStyle?.backgroundColor,
              !backgroundColor.getAdaptiveColor(colorScheme).isEmpty else {
            return false
        }
        return true
    }

    var hasBackgroundImage: Bool {
        guard let backgroundImage = backgroundStyle?.backgroundImage,
              !backgroundImage.url.light.isEmpty else {
            return false
        }
        return true
    }

    func body(content: Content) -> some View {
        content
            .backgroundImage(backgroundImage: backgroundStyle?.backgroundImage, imageLoader: imageLoader)
            .backgroundColor(hex: backgroundStyle?.backgroundColor?.getAdaptiveColor(colorScheme))
    }
}

@available(iOS 15, *)
struct BackgroundColorModifier: ViewModifier {
    let backgroundColor: String?

    func body(content: Content) -> some View {
        content.background(Color(hex: backgroundColor ?? ""))
    }
}

@available(iOS 15, *)
struct BackgroundImageModifier: ViewModifier {
    let backgroundImage: BackgroundImage?
    let imageLoader: RoktUXImageLoader?
    var hasBackgroundImage: Bool { backgroundImage?.url != nil && backgroundImage?.url.light.isEmpty == false }
    var bgAlignment: Alignment { (backgroundImage?.position ?? .center).getAlignment() }

    @State private var isImageValid = false

    func body(content: Content) -> some View {
        content.background(alignment: bgAlignment) {
            hasBackgroundImage ?
                AnyView(AsyncImageView(imageUrl: backgroundImage?.url,
                                       scale: backgroundImage?.scale,
                                       imageLoader: imageLoader,
                                       isImageValid: $isImageValid)) :
                AnyView(EmptyView())
        }
        .clipped()
    }
}
