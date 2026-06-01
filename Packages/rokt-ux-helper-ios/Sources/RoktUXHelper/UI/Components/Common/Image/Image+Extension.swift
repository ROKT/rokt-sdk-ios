import SwiftUI
import DcuiSchema

@available(iOS 15.0, *)
extension Image {
    func scaleIfNeeded(scale: BackgroundImageScale?) -> some View {
        switch scale {
        case .crop:
            return AnyView(self) // No resizing or scaling
        default:
            return AnyView(self
                .resizable()
                .aspectRatio(contentMode: scale?.getScale() ?? .fit))
        }
    }
}
