import SwiftUI
@testable import RoktUXHelper

@available(iOS 15.0, *)
struct TestOverlayPlaceholder: View {
    let layout: OverlayViewModel
    var layoutState = LayoutState()
    var body: some View {
        OverlayComponent(model: layout)
    }
}
