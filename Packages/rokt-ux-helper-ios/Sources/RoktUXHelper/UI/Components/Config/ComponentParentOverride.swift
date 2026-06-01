import SwiftUI
import DcuiSchema

@available(iOS 15, *)
struct ComponentParentOverride {
    let parentVerticalAlignment: VerticalAlignment?
    let parentHorizontalAlignment: HorizontalAlignment?
    let parentBackgroundStyle: BackgroundStylingProperties?
    let stretchChildren: Bool?

    func updateBackground(_ backgroundStyle: BackgroundStylingProperties?) -> ComponentParentOverride {
        return ComponentParentOverride(parentVerticalAlignment: parentVerticalAlignment,
                                       parentHorizontalAlignment: parentHorizontalAlignment,
                                       parentBackgroundStyle: backgroundStyle,
                                       stretchChildren: stretchChildren)
    }
}
