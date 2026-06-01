import SwiftUI
import Combine
import DcuiSchema

@available(iOS 15, *)
struct ImageCarouselIndicator: View {
    let config: ComponentConfig
    @StateObject var model: ImageCarouselIndicatorViewModel

    @Binding var styleState: StyleState

    @Binding var parentWidth: CGFloat?
    @Binding var parentHeight: CGFloat?

    @EnvironmentObject var globalScreenSize: GlobalScreenSize

    @State var frameChangeIndex: Int = 0

    let parentOverride: ComponentParentOverride?

    var style: BaseStyles? {
        model.defaultStyle?[safe: model.breakpointIndex]
    }
    var containerStyle: ContainerStylingProperties? { style?.container }
    var dimensionStyle: DimensionStylingProperties? { style?.dimension }
    var flexStyle: FlexChildStylingProperties? { style?.flexChild }
    var borderStyle: BorderStylingProperties? { style?.border }
    var spacingStyle: SpacingStylingProperties? { style?.spacing }
    var backgroundStyle: BackgroundStylingProperties? { style?.background }

    var verticalAlignmentOverride: VerticalAlignment? {
        containerStyle?.justifyContent?.asVerticalAlignment.vertical
    }
    var horizontalAlignmentOverride: HorizontalAlignment? {
        containerStyle?.alignItems?.asHorizontalAlignment.horizontal
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

    var body: some View {
        createContainer()
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
                parentOverride: parentOverride?.updateBackground(backgroundStyle),
                verticalAlignmentOverride: verticalAlignmentOverride,
                horizontalAlignmentOverride: horizontalAlignmentOverride,
                defaultHeight: .wrapContent,
                defaultWidth: .wrapContent,
                isContainer: true,
                containerType: .row,
                frameChangeIndex: .constant(0),
                imageLoader: model.imageLoader
            )
            .readSize(spacing: spacingStyle) { size in
                model.shouldUpdate(size)
            }
            .onChange(of: globalScreenSize.width) { newSize in
                DispatchQueue.main.async {
                    // update breakpoint index
                    model.shouldUpdateBreakpoint(newSize)
                }
            }
    }

    func createContainer() -> some View {
        HStack(alignment: rowPerpendicularAxisAlignment(alignItems: containerStyle?.alignItems),
               spacing: CGFloat(containerStyle?.gap ?? 0)) {
            ForEach(model.rowViewModels) { viewModel in
                RowComponent(
                    config: config,
                    model: viewModel,
                    parentWidth: $model.availableWidth,
                    parentHeight: $model.availableHeight,
                    styleState: $model.styleState,
                    parentOverride: parentOverride?.updateBackground(backgroundStyle)
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(true)
    }
}
