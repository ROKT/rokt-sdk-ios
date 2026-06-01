import SwiftUI
import DcuiSchema

@available(iOS 15, *)
struct ResizableBottomSheetComponent: View {
    @SwiftUI.Environment(\.colorScheme) var colorScheme
    let model: BottomSheetViewModel
    let onSizeChange: ((CGFloat) -> Void)?
    var style: BottomSheetStyles? {
        model.defaultStyle?.count ?? -1 > breakpointIndex ? model.defaultStyle?[breakpointIndex] : nil
    }

    @State var breakpointIndex = 0
    @State var lastUpdatedHeight: CGFloat = 0

    @State private var availableWidth: CGFloat?
    @State private var availableHeight: CGFloat?

    @StateObject var globalScreenSize = GlobalScreenSize()
    var body: some View {
        ScrollView {
            OuterLayerComponent(layouts: model.children,
                                style: StylingPropertiesModel(
                                    container: style?.container,
                                    background: style?.background,
                                    dimension: updateBottomSheetHeight(dimension: style?.dimension),
                                    flexChild: style?.flexChild,
                                    spacing: style?.spacing,
                                    border: style?.border
                                ),
                                layoutState: model.layoutState,
                                eventService: model.eventService,
                                parentWidth: $availableWidth,
                                parentHeight: $availableHeight,
                                onSizeChange: onBottomSheetSizeChange)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(backgroundStyle: style?.background, imageLoader: model.imageLoader)
            .readSize(spacing: style?.spacing) { size in
                availableWidth = size.width
                availableHeight = size.height

                // 0 at the start
                globalScreenSize.width = size.width
                globalScreenSize.height = size.height
            }
            .environmentObject(globalScreenSize)
            .onChange(of: globalScreenSize.width) { newSize in
                DispatchQueue.main.async {
                    breakpointIndex = model.updateBreakpointIndex(for: newSize)
                }
            }
        }
        .bounceBasedOnSize()
        .background(backgroundStyle: style?.background, imageLoader: model.imageLoader)
    }

    func onBottomSheetSizeChange(newHeight: CGFloat) {
        var adjustedHeight = newHeight
        if let padding = style?.spacing?.padding {
            let paddingFrame = FrameAlignmentProperty.getFrameAlignment(padding)
            adjustedHeight += paddingFrame.top + paddingFrame.bottom
        }

        if let margin = style?.spacing?.margin {
            let marginFrame = FrameAlignmentProperty.getFrameAlignment(margin)
            adjustedHeight += marginFrame.top + marginFrame.bottom
        }

        onSizeChange?(adjustedHeight)
    }

    // BottomSheet height has to be wrapContent
    private func updateBottomSheetHeight(dimension: DimensionStylingProperties?) -> DimensionStylingProperties? {
        guard let dimension, dimension.height != nil else { return dimension }

            return DimensionStylingProperties(minWidth: dimension.minWidth,
                                              maxWidth: dimension.maxWidth,
                                              width: dimension.width,
                                              minHeight: dimension.minHeight,
                                              maxHeight: dimension.maxHeight,
                                              height: .fit(.wrapContent),
                                              rotateZ: dimension.rotateZ)

    }
}
