import SwiftUI
import DcuiSchema

@available(iOS 15, *)
struct ColumnComponent: View {
    @SwiftUI.Environment(\.colorScheme) var colorScheme

    var style: ColumnStyle? {
        switch styleState {
        case .hovered:
            return model.hoveredStyle?.count ?? -1 > breakpointIndex ? model.hoveredStyle?[breakpointIndex] : nil
        case .pressed:
            return model.pressedStyle?.count ?? -1 > breakpointIndex ? model.pressedStyle?[breakpointIndex] : nil
        case .disabled:
            return model.disabledStyle?.count ?? -1 > breakpointIndex ? model.disabledStyle?[breakpointIndex] : nil
        default:
            return model.defaultStyle?.count ?? -1 > breakpointIndex ? model.defaultStyle?[breakpointIndex] : nil
        }
    }

    @EnvironmentObject var globalScreenSize: GlobalScreenSize
    @State var breakpointIndex: Int = 0
    @State var frameChangeIndex: Int = 0

    var containerStyle: ContainerStylingProperties? { style?.container }
    var dimensionStyle: DimensionStylingProperties? { style?.dimension }
    var flexStyle: FlexChildStylingProperties? { style?.flexChild }
    var borderStyle: BorderStylingProperties? { style?.border }
    var spacingStyle: SpacingStylingProperties? { style?.spacing }
    var backgroundStyle: BackgroundStylingProperties? { style?.background }

    let config: ComponentConfig
    let model: ColumnViewModel

    @Binding var parentWidth: CGFloat?
    @Binding var parentHeight: CGFloat?
    @Binding var styleState: StyleState
    @State private var availableWidth: CGFloat?
    @State private var availableHeight: CGFloat?

    let parentOverride: ComponentParentOverride?

    var passableBackgroundStyle: BackgroundStylingProperties? {
        backgroundStyle ?? parentOverride?.parentBackgroundStyle
    }

    var verticalAlignment: VerticalAlignmentProperty {
        if let justifyContent = containerStyle?.justifyContent?.asVerticalAlignmentProperty {
            return justifyContent
        } else if let parentAlign = parentOverride?.parentVerticalAlignment?.asVerticalAlignmentProperty {
            return parentAlign
        } else {
            return .top
        }
    }

    var horizontalAlignment: HorizontalAlignmentProperty {
        if let alignItems = containerStyle?.alignItems?.asHorizontalAlignmentProperty {
            return alignItems
        } else if let parentAlign = parentOverride?.parentHorizontalAlignment?.asHorizontalAlignmentProperty {
            return parentAlign
        } else {
            return .start
        }
    }

    var accessibilityBehavior: AccessibilityChildBehavior {
        model.accessibilityGrouped ? .combine : .contain
    }

    var body: some View {
        build()
            .applyLayoutModifier(
                verticalAlignmentProperty: verticalAlignment,
                horizontalAlignmentProperty: horizontalAlignment,
                spacing: spacingStyle,
                dimension: dimensionStyle,
                flex: flexStyle,
                border: borderStyle,
                background: backgroundStyle,
                container: containerStyle,
                parent: config.parent,
                parentWidth: $parentWidth,
                parentHeight: $parentHeight,
                parentOverride: parentOverride?.updateBackground(passableBackgroundStyle),
                defaultHeight: .wrapContent,
                defaultWidth: .wrapContent,
                isContainer: true,
                containerType: .column,
                frameChangeIndex: $frameChangeIndex,
                imageLoader: model.imageLoader
            )
            .readSize(spacing: spacingStyle) { size in
                availableWidth = size.width
                availableHeight = size.height
            }
            .onChange(of: globalScreenSize.width) { newSize in
                DispatchQueue.main.async {
                    breakpointIndex = model.updateBreakpointIndex(for: newSize)
                    frameChangeIndex += 1
                }
            }
            .accessibilityElement(children: accessibilityBehavior)
    }

    private func build() -> some View {
        // `alignment` = children edge alignment in the horizontal direction
        return VStack(alignment: columnPerpendicularAxisAlignment(alignItems: containerStyle?.alignItems),
                      spacing: CGFloat(containerStyle?.gap ?? 0)) {
            if let children = model.children {
                ForEach(children, id: \.self) { child in
                    LayoutSchemaComponent(config: config.updateParent(.column),
                                          layout: child,
                                          parentWidth: $availableWidth,
                                          parentHeight: $availableHeight,
                                          styleState: $styleState,
                                          parentOverride:
                                            ComponentParentOverride(
                                                parentVerticalAlignment:
                                                    columnPrimaryAxisAlignment(justifyContent:
                                                                                containerStyle?.justifyContent).asVerticalType,
                                                parentHorizontalAlignment:
                                                    columnPerpendicularAxisAlignment(alignItems:
                                                                                        containerStyle?.alignItems),
                                                parentBackgroundStyle: passableBackgroundStyle,
                                                stretchChildren: containerStyle?.alignItems == .stretch
                                            ))
                }
            }
        }
    }
}
