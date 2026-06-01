import SwiftUI
import DcuiSchema

@available(iOS 15, *)
struct RowComponent: View {
    @SwiftUI.Environment(\.colorScheme) var colorScheme

    var style: BaseStyles? {
        switch styleState {
        case .hovered:
            model.stylingProperties?[safe: breakpointIndex]?.hovered
        case .pressed:
            model.stylingProperties?[safe: breakpointIndex]?.pressed
        case .disabled:
            model.stylingProperties?[safe: breakpointIndex]?.disabled
        default:
            model.stylingProperties?[safe: breakpointIndex]?.default
        }
    }

    @EnvironmentObject var globalScreenSize: GlobalScreenSize
    @State var breakpointIndex: Int = 0
    @State var frameChangeIndex: Int = 0

    var containerStyle: ContainerStylingProperties? { (currentStyle ?? style)?.container }
    var dimensionStyle: DimensionStylingProperties? { (currentStyle ?? style)?.dimension }
    var flexStyle: FlexChildStylingProperties? { (currentStyle ?? style)?.flexChild }
    var borderStyle: BorderStylingProperties? { (currentStyle ?? style)?.border }
    var spacingStyle: SpacingStylingProperties? { (currentStyle ?? style)?.spacing }
    var backgroundStyle: BackgroundStylingProperties? { (currentStyle ?? style)?.background }

    let config: ComponentConfig
    @ObservedObject var model: RowViewModel

    @Binding var parentWidth: CGFloat?
    @Binding var parentHeight: CGFloat?
    @Binding var styleState: StyleState
    @State private var availableWidth: CGFloat?
    @State private var availableHeight: CGFloat?
    @State private var currentStyle: BaseStyles?

    let parentOverride: ComponentParentOverride?

    var passableBackgroundStyle: BackgroundStylingProperties? {
        backgroundStyle ?? parentOverride?.parentBackgroundStyle
    }

    var verticalAlignment: VerticalAlignmentProperty {
        if let justifyContent = containerStyle?.alignItems?.asVerticalAlignmentProperty {
            return justifyContent
        } else if let parentAlign = parentOverride?.parentVerticalAlignment?.asVerticalAlignmentProperty {
            return parentAlign
        } else {
            return .top
        }
    }

    var horizontalAlignment: HorizontalAlignmentProperty {
        if let alignItems = containerStyle?.justifyContent?.asHorizontalAlignmentProperty {
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
                defaultWidth: .fitWidth,
                isContainer: true,
                containerType: .row,
                frameChangeIndex: $frameChangeIndex,
                imageLoader: model.imageLoader
            )
            .readSize(spacing: spacingStyle) { size in
                availableWidth = size.width
                availableHeight = size.height
            }
            .onChange(of: globalScreenSize.width) { newSize in
                model.width = newSize ?? 0
                DispatchQueue.main.async {
                    breakpointIndex = model.updateBreakpointIndex(for: newSize)
                    frameChangeIndex += 1
                    updateStyle()
                }
            }
            .accessibilityElement(children: accessibilityBehavior)
            .onLoad {
                currentStyle = style
                updateStyle()
                // Pass the config to the model as early as possible
                model.componentConfig = config
            }
            .onChange(of: model.animate) { _ in
                updateStyle()
            }
    }

    private func updateStyle() {
        if model.animate {
            withAnimation(.linear(duration: model.animatableStyle?.duration ?? 0)) {
                currentStyle = .union(style, diff: model.animatableStyle?.style)
            }
        } else {
            currentStyle = style
        }
    }

    func build() -> some View {
        return HStack(alignment: rowPerpendicularAxisAlignment(alignItems: containerStyle?.alignItems),
                      spacing: CGFloat(containerStyle?.gap ?? 0)) {
            if let children = model.children {
                ForEach(children, id: \.self) { child in
                    LayoutSchemaComponent(
                        config: config.updateParent(.row),
                        layout: child,
                        parentWidth: $availableWidth,
                        parentHeight: $availableHeight,
                        styleState: $styleState,
                        parentOverride:
                            ComponentParentOverride(
                                parentVerticalAlignment: rowPerpendicularAxisAlignment(
                                    alignItems: containerStyle?.alignItems
                                ),
                                parentHorizontalAlignment: rowPrimaryAxisAlignment(
                                    justifyContent: containerStyle?.justifyContent
                                ).asHorizontalType,
                                parentBackgroundStyle: passableBackgroundStyle,
                                stretchChildren: containerStyle?.alignItems == .stretch
                            )
                    )
                }
            }
        }
    }
}
