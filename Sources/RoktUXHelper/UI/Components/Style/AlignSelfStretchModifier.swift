import SwiftUI
import DcuiSchema

@available(iOS 15, *)
struct AlignSelfStretchModifier {
    enum Constant {
        static let defaultVerticalAlignment = VerticalAlignment.center
        static let defaultHorizontalAlignment = HorizontalAlignment.center
    }

    let alignSelf: FlexAlignment?
    let parent: ComponentParentType
    let parentHeight: CGFloat?
    let parentWidth: CGFloat?

    let parentOverride: ComponentParentOverride?

    let wrapperAlignment: Alignment?
    let frameMaxWidth: CGFloat?
    let frameMaxHeight: CGFloat?

    let rowAlignmentOverride: VerticalAlignment?
    let columnAlignmentOverride: HorizontalAlignment?

    init(
        alignSelf: FlexAlignment?,
        parent: ComponentParentType,
        parentHeight: CGFloat?,
        parentWidth: CGFloat?,
        parentOverride: ComponentParentOverride?,
        rowAlignmentOverride: VerticalAlignment? = nil,
        columnAlignmentOverride: HorizontalAlignment? = nil
    ) {
        self.alignSelf = alignSelf
        self.parent = parent
        self.parentHeight = parentHeight
        self.parentWidth = parentWidth
        self.parentOverride = parentOverride
        self.rowAlignmentOverride = rowAlignmentOverride
        self.columnAlignmentOverride = columnAlignmentOverride
        self.wrapperAlignment = AlignSelfStretchModifier.getWrapperAlignment(
            parent: parent,
            parentRowAlignment: parentOverride?.parentVerticalAlignment,
            parentColumnAlignment: parentOverride?.parentHorizontalAlignment,
            rowAlignmentOverride: rowAlignmentOverride,
            columnAlignmentOverride: columnAlignmentOverride
        )
        self.frameMaxWidth = AlignSelfStretchModifier.getFrameMaxWidth(
            alignSelf: alignSelf,
            strechChildren: parentOverride?.stretchChildren,
            parent: parent
        )
        self.frameMaxHeight = AlignSelfStretchModifier.getFrameMaxHeight(
            alignSelf: alignSelf,
            strechChildren: parentOverride?.stretchChildren,
            parent: parent
        )

    }

    private static func getWrapperAlignment(
        parent: ComponentParentType,
        parentRowAlignment: VerticalAlignment?,
        parentColumnAlignment: HorizontalAlignment?,
        rowAlignmentOverride: VerticalAlignment? = nil,
        columnAlignmentOverride: HorizontalAlignment? = nil
    ) -> Alignment? {
        switch parent {
        case .row:
            if let rowAlignmentOverride {
                return rowAlignmentOverride.asRowAlignment
            } else {
                return parentRowAlignment?.asRowAlignment
            }
        case .column:
            if let columnAlignmentOverride {
                return columnAlignmentOverride.asColumnAlignment
            } else {
                return parentColumnAlignment?.asColumnAlignment
            }
        case .root:
            return .center
        }
    }
    private static func getFrameMaxWidth(
        alignSelf: FlexAlignment?,
        strechChildren: Bool? = false,
        parent: ComponentParentType
    ) -> CGFloat? {
        guard alignSelf == .stretch || strechChildren == true else {
            return nil
        }
        switch parent {
        case .column:
            return .infinity
        default:
            return nil
        }
    }
    private static func getFrameMaxHeight(
        alignSelf: FlexAlignment?,
        strechChildren: Bool? = false,
        parent: ComponentParentType
    ) -> CGFloat? {
        guard alignSelf == .stretch || strechChildren == true else {
            return nil
        }
        switch parent {
        case .row:
            return .infinity
        default:
            return nil
        }
    }
}
