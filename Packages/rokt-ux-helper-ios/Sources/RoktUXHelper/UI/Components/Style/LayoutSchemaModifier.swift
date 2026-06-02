import SwiftUI
import DcuiSchema

@available(iOS 15, *)
struct LayoutSchemaModifier: ViewModifier, SpacingStyleable {
    let verticalAlignmentProperty: VerticalAlignmentProperty
    let horizontalAlignmentProperty: HorizontalAlignmentProperty

    let spacing: SpacingStylingProperties?
    let dimension: DimensionStylingProperties?
    let flex: FlexChildStylingProperties?
    let border: BorderStylingProperties?
    let background: BackgroundStylingProperties?
    let container: CommonContainerStylingProperties?

    let parent: ComponentParentType

    @Binding var parentWidth: CGFloat?
    @Binding var parentHeight: CGFloat?

    let parentOverride: ComponentParentOverride?

    let verticalAlignmentOverride: VerticalAlignment?
    let horizontalAlignmentOverride: HorizontalAlignment?

    let defaultHeight: HeightFitProperty
    let defaultWidth: WidthFitProperty

    let expandsToContainerOnSelfAlign: Bool
    let isContainer: Bool
    let containerType: ComponentParentType
    let applyAlignSelf: Bool
    let applyMargin: Bool
    @Binding var frameChangeIndex: Int
    let imageLoader: RoktUXImageLoader?

    func body(content: Content) -> some View {
        content
            .padding(frame: getPadding())
            // HAS TO BE APPLIED BEFORE BACKGROUND
            .frame(dimension: dimension,
                   weight: flex?.weight,
                   parent: parent,
                   defaultWidth: defaultWidth,
                   parentWidth: parentWidth,
                   defaultHeight: defaultHeight,
                   parentHeight: parentHeight,
                   horizontalAxisAlignment: horizontalAlignmentProperty.getAlignment(),
                   verticalAxisAlignment: verticalAlignmentProperty.getAlignment(),
                   alignSelf: flex?.alignSelf,
                   parentOverride: parentOverride,
                   margin: getMargin())
            .background(backgroundStyle: background, imageLoader: imageLoader)
            .border(
                borderRadius: border?.borderRadius,
                borderColor: border?.borderColor,
                borderWidth: border?.borderWidth,
                borderStyle: border?.borderStyle
            )
            .ifLet(container?.overflow) { $0.overflow(overflow: $1) }
            .ifLet(container?.blur) { $0.blur(blur: $1) }
            .shadow(
                backgroundColor: parentOverride?.parentBackgroundStyle?.backgroundColor,
                borderRadius: border?.borderRadius,
                xOffset: container?.shadow?.offsetX,
                yOffset: container?.shadow?.offsetY,
                shadowColor: container?.shadow?.color,
                blurRadius: container?.shadow?.blurRadius,
                isContainer: isContainer
            )
            .offset(offset: getOffset())
            .ifLet(dimension?.rotateZ) { $0.rotate(rotateZ: $1) }
            // HAS TO BE APPLIED AFTER BACKGROUND BUT BEFORE MARGIN
            .alignSelf(
                alignSelf: flex?.alignSelf,
                parent: parent,
                parentHeight: parentHeight,
                parentWidth: parentWidth,
                parentVerticalAlignment: parentOverride?.parentVerticalAlignment,
                parentHorizontalAlignment: parentOverride?.parentHorizontalAlignment,
                rowAlignmentOverride: verticalAlignmentOverride,
                columnAlignmentOverride: horizontalAlignmentOverride,
                expandsToContainerOnSelfAlign: expandsToContainerOnSelfAlign,
                applyAlignSelf: applyAlignSelf
            )
            .equalStretch(containerType: containerType,
                          isContainer: isContainer,
                          stretchChildren: container?.alignItems == .stretch,
                          breakpointIndex: $frameChangeIndex)
            .margin(spacing: spacing,
                    applyMargin: applyMargin)
    }
}

@available(iOS 15, *)
internal extension View {
    func applyLayoutModifier(
        verticalAlignmentProperty: VerticalAlignmentProperty,
        horizontalAlignmentProperty: HorizontalAlignmentProperty,
        spacing: SpacingStylingProperties?,
        dimension: DimensionStylingProperties?,
        flex: FlexChildStylingProperties?,
        border: BorderStylingProperties?,
        background: BackgroundStylingProperties?,
        container: CommonContainerStylingProperties? = nil,
        parent: ComponentParentType,
        parentWidth: Binding<CGFloat?>,
        parentHeight: Binding<CGFloat?>,
        parentOverride: ComponentParentOverride?,
        verticalAlignmentOverride: VerticalAlignment? = nil,
        horizontalAlignmentOverride: HorizontalAlignment? = nil,
        defaultHeight: HeightFitProperty,
        defaultWidth: WidthFitProperty,
        expandsToContainerOnSelfAlign: Bool = false,
        isContainer: Bool = false,
        containerType: ComponentParentType = .column,
        applyAlignSelf: Bool = true,
        applyMargin: Bool = true,
        frameChangeIndex: Binding<Int> = .constant(0),
        imageLoader: RoktUXImageLoader?
    ) -> some View {
        modifier(LayoutSchemaModifier(
            verticalAlignmentProperty: verticalAlignmentProperty,
            horizontalAlignmentProperty: horizontalAlignmentProperty,
            spacing: spacing,
            dimension: dimension,
            flex: flex,
            border: border,
            background: background,
            container: container,
            parent: parent,
            parentWidth: parentWidth,
            parentHeight: parentHeight,
            parentOverride: parentOverride,
            verticalAlignmentOverride: verticalAlignmentOverride,
            horizontalAlignmentOverride: horizontalAlignmentOverride,
            defaultHeight: defaultHeight,
            defaultWidth: defaultWidth,
            expandsToContainerOnSelfAlign: expandsToContainerOnSelfAlign,
            isContainer: isContainer,
            containerType: containerType,
            applyAlignSelf: applyAlignSelf,
            applyMargin: applyMargin,
            frameChangeIndex: frameChangeIndex,
            imageLoader: imageLoader
        ))
    }
}
