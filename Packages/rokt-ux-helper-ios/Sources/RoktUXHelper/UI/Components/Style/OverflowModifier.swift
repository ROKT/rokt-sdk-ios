import SwiftUI
import DcuiSchema

@available(iOS 15, *)
struct OverflowModifier: ViewModifier {
    let overFlow: Overflow?

    func body(content: Content) -> some View {
        switch overFlow {
        case .hidden:
            content.clipped()
        default: // nil and visibile
            content
        }
    }

}
