import SwiftUI
import DcuiSchema

@available(iOS 15, *)
struct ScrollableRowComponent: View {
    @SwiftUI.Environment(\.colorScheme) var colorScheme

    let config: ComponentConfig
    let model: RowViewModel

    @Binding var parentWidth: CGFloat?
    @Binding var parentHeight: CGFloat?
    @Binding var styleState: StyleState
    @State private var availableWidth: CGFloat?
    @State private var availableHeight: CGFloat?
    @State private var contentMaxWidth: CGFloat = .zero
    @State private var contentAlignment: Alignment = .center // SwiftUI default frame alignment

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

    @State var breakpointIndex: Int = 0

    var containerStyle: ContainerStylingProperties? { style?.container }
    var dimensionStyle: DimensionStylingProperties? { style?.dimension }
    var flexStyle: FlexChildStylingProperties? { style?.flexChild }

    let parentOverride: ComponentParentOverride?

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

    var weightProperties: WeightModifier.Properties {
        WeightModifier.Properties(weight: flexStyle?.weight,
                                  parent: .row,
                                  verticalAlignment: verticalAlignment.getAlignment(),
                                  horizontalAlignment: horizontalAlignment.getAlignment())
    }

    var dimensionMaxWidth: CGFloat? {
        let widthModifier = WidthModifier(
            widthProperty: dimensionStyle?.width,
            minimum: dimensionStyle?.minWidth,
            maximum: dimensionStyle?.maxWidth,
            alignment: horizontalAlignment.getAlignment(),
            defaultWidth: .wrapContent,
            parentWidth: parentWidth
        )
        return widthModifier.frameMaxWidth
    }

    var body: some View {
        ScrollView(.horizontal) {
            RowComponent(config: config,
                         model: model,
                         parentWidth: $parentWidth,
                         parentHeight: $parentHeight,
                         styleState: $styleState,
                         parentOverride: parentOverride)
            .readSize(weightProperties: weightProperties) { newSizeWithMax, newAlignment in
                if let dimensionMax = dimensionMaxWidth {
                    contentMaxWidth = dimensionMax
                } else if let weightMaxWidth = newSizeWithMax.maxWidth {
                    contentMaxWidth = weightMaxWidth
                } else {
                    contentMaxWidth = newSizeWithMax.size.width
                }
                contentAlignment = newAlignment
            }
        }
        .frame(maxWidth: contentMaxWidth, alignment: contentAlignment)
    }

}
