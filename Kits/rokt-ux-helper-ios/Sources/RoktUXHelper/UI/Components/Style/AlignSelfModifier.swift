import SwiftUI
import DcuiSchema

@available(iOS 15, *)
struct AlignSelfModifier: ViewModifier {
    private enum Constant {
        static let defaultAlignment = Alignment.center
    }

    let alignSelf: FlexAlignment?

    let parent: ComponentParentType
    let parentHeight: CGFloat?
    let parentWidth: CGFloat?

    let parentRowAlignment: VerticalAlignment?
    let parentColumnAlignment: HorizontalAlignment?

    internal let wrapperAlignment: Alignment?
    private let frameMaxWidth: CGFloat?
    private let frameMaxHeight: CGFloat?

    let rowAlignmentOverride: VerticalAlignment?
    let columnAlignmentOverride: HorizontalAlignment?

    let expandsToContainerOnSelfAlign: Bool
    let applyAlignSelf: Bool

    init(
        alignSelf: FlexAlignment?,
        parent: ComponentParentType,
        parentHeight: CGFloat?,
        parentWidth: CGFloat?,
        parentRowAlignment: VerticalAlignment? = nil,
        parentColumnAlignment: HorizontalAlignment? = nil,
        rowAlignmentOverride: VerticalAlignment? = nil,
        columnAlignmentOverride: HorizontalAlignment? = nil,
        expandsToContainerOnSelfAlign: Bool = false,
        applyAlignself: Bool
    ) {
        self.alignSelf = alignSelf
        self.parent = parent
        self.parentHeight = parentHeight
        self.parentWidth = parentWidth
        self.parentRowAlignment = parentRowAlignment
        self.parentColumnAlignment = parentColumnAlignment
        self.rowAlignmentOverride = rowAlignmentOverride
        self.columnAlignmentOverride = columnAlignmentOverride
        self.expandsToContainerOnSelfAlign = expandsToContainerOnSelfAlign
        self.applyAlignSelf = applyAlignself

        self.wrapperAlignment = AlignSelfModifier.getWrapperAlignment(
            alignSelf: alignSelf,
            parent: parent,
            parentRowAlignment: parentRowAlignment,
            parentColumnAlignment: parentColumnAlignment,
            rowAlignmentOverride: rowAlignmentOverride,
            columnAlignmentOverride: columnAlignmentOverride
        )
        self.frameMaxWidth = AlignSelfModifier.getFrameMaxWidth(
            alignSelf: alignSelf,
            parent: parent,
            parentWidth: parentWidth
        )
        self.frameMaxHeight = AlignSelfModifier.getFrameMaxHeight(
            alignSelf: alignSelf,
            parent: parent,
            parentHeight: parentHeight,
            expandsToContainerOnSelfAlign: expandsToContainerOnSelfAlign
        )
    }

    func body(content: Content) -> some View {
        if !applyAlignSelf || alignSelf == nil || alignSelf == .stretch {
            content
        } else {
            content
                .frame(maxWidth: frameMaxWidth,
                       maxHeight: frameMaxHeight,
                       alignment: wrapperAlignment ?? Constant.defaultAlignment)
        }
    }

    private static func getWrapperAlignment(
        alignSelf: FlexAlignment?,
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
                return alignSelf?.asRowAlignment ?? parentRowAlignment?.asRowAlignment
            }
        case .column:
            if let columnAlignmentOverride {
                return columnAlignmentOverride.asColumnAlignment
            } else {
                return alignSelf?.asColumnAlignment ?? parentColumnAlignment?.asColumnAlignment
            }
        case .root:
            return .center
        }
    }

    private static func getFrameMaxWidth(alignSelf: FlexAlignment?,
                                         parent: ComponentParentType,
                                         parentWidth: CGFloat?) -> CGFloat? {
        switch parent {
        case .column:
            return parentWidth
        default:
            return nil
        }
    }

    private static func getFrameMaxHeight(alignSelf: FlexAlignment?,
                                          parent: ComponentParentType,
                                          parentHeight: CGFloat?,
                                          expandsToContainerOnSelfAlign: Bool) -> CGFloat? {
        switch parent {
        case .row:
            return parentHeight
        case .column:
            if expandsToContainerOnSelfAlign {
                return parentHeight
            } else {
                return nil
            }
        default:
            return nil
        }
    }
}

@available(iOS 13, *)
extension VerticalAlignment {
    var asRowAlignment: Alignment {
        switch self {
        case .top:
            return .top
        case .bottom:
            return .bottom
        case .center:
            return .center
        default:
            return .center
        }
    }
}

@available(iOS 13, *)
extension HorizontalAlignment {
    var asColumnAlignment: Alignment {
        switch self {
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        case .center:
            return .center
        default:
            return .center
        }
    }
}

@available(iOS 13, *)
extension FlexAlignment {
    var asRowAlignment: Alignment {
        switch self {
        case .flexStart:
            return .top
        case .flexEnd:
            return .bottom
        case .center, .stretch:
            return .center
        }
    }

    var asColumnAlignment: Alignment {
        switch self {
        case .flexStart:
            return .leading
        case .flexEnd:
            return .trailing
        case .center, .stretch:
            return .center
        }
    }
}

@available(iOS 13, *)
extension FlexJustification {
    var asRowAlignment: Alignment {
        switch self {
        case .flexStart:
            return .top
        case .flexEnd:
            return .bottom
        case .center:
            return .center
        }
    }

    var asColumnAlignment: Alignment {
        switch self {
        case .flexStart:
            return .leading
        case .flexEnd:
            return .trailing
        case .center:
            return .center
        }
    }
}
