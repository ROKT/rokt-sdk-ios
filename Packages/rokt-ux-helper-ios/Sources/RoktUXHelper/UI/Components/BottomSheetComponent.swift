import SwiftUI
import DcuiSchema

@available(iOS 15, *)
struct BottomSheetComponent: View {
    @SwiftUI.Environment(\.colorScheme) var colorScheme
    let model: BottomSheetViewModel
    var style: BottomSheetStyles? {
        model.defaultStyle?.count ?? -1 > breakpointIndex ? model.defaultStyle?[breakpointIndex] : nil
    }

    @State var breakpointIndex = 0

    @State private var availableWidth: CGFloat?
    @State private var availableHeight: CGFloat?

    @StateObject var globalScreenSize = GlobalScreenSize()
    var body: some View {
        OuterLayerComponent(layouts: model.children,
                            style: StylingPropertiesModel(
                                container: style?.container,
                                background: style?.background,
                                dimension: updateButtomSheetHeight(dimension: style?.dimension),
                                flexChild: style?.flexChild,
                                spacing: style?.spacing,
                                border: style?.border
                            ),
                            layoutState: model.layoutState,
                            eventService: model.eventService,
                            parentWidth: $availableWidth,
                            parentHeight: $availableHeight)
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

    // BottomSheet height already applied to the viewController level
    // if height value is percentage, instead of applying percentage, need to use fit-height
    // to occupy whole area instead of applying percentage twice
    private func updateButtomSheetHeight(dimension: DimensionStylingProperties?) -> DimensionStylingProperties? {
        guard let dimension, let height = dimension.height else { return dimension }
        switch height {
        case .percentage:
            return DimensionStylingProperties(minWidth: dimension.minWidth,
                                              maxWidth: dimension.maxWidth,
                                              width: dimension.width,
                                              minHeight: dimension.minHeight,
                                              maxHeight: dimension.maxHeight,
                                              height: .fit(.fitHeight),
                                              rotateZ: dimension.rotateZ)
        default:
            return dimension
        }
    }
}
