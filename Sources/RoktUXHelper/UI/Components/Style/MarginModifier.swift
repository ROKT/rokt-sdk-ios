import SwiftUI
import DcuiSchema

@available(iOS 15, *)
struct MarginModifier: ViewModifier, SpacingStyleable {
    let spacing: SpacingStylingProperties?
    let applyMargin: Bool

    func body(content: Content) -> some View {
        let frame = applyMargin ? getMargin() : FrameAlignmentProperty.zeroDimension
        content.padding(frame: frame)
    }

}
