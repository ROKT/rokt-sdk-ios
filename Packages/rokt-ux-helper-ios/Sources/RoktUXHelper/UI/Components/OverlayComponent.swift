import SwiftUI
import DcuiSchema

@available(iOS 15, *)
struct OverlayComponent: View {
    @SwiftUI.Environment(\.colorScheme) var colorScheme
    let model: OverlayViewModel
    var wrapperStyle: OverlayWrapperStyles? {
        model.wrapperStyle?.count ?? -1 > breakpointIndex ? model.wrapperStyle?[breakpointIndex] : nil
    }
    var style: OverlayStyles? {
        model.defaultStyle?.count ?? -1 > breakpointIndex ? model.defaultStyle?[breakpointIndex] : nil
    }

    @State var breakpointIndex = 0

    @State private var availableWidth: CGFloat?
    @State private var availableHeight: CGFloat?

    @StateObject var globalScreenSize = GlobalScreenSize()
    var body: some View {
        ZStack(alignment: getOverlayAlignment()) {
            if model.allowBackdropToClose ?? false {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        model.layoutState?.actionCollection[.close](nil)
                    }
            }
            build()
        }
        .frame(maxWidth: .infinity,
               maxHeight: .infinity,
               alignment: getOverlayAlignment())
        .background(backgroundStyle: wrapperStyle?.background,
                    imageLoader: model.imageLoader)
        .overflow(overflow: wrapperStyle?.container?.overflow)
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

    private func build() -> OuterLayerComponent {
        return OuterLayerComponent(layouts: model.children,
                                   style: StylingPropertiesModel(
                                       container: style?.container,
                                       background: style?.background,
                                       dimension: style?.dimension,
                                       flexChild: style?.flexChild,
                                       spacing: style?.spacing,
                                       border: style?.border
                                   ),
                                   layoutState: model.layoutState,
                                   eventService: model.eventService,
                                   parentWidth: $availableWidth,
                                   parentHeight: $availableHeight)
    }

    private func getOverlayAlignment() -> Alignment {
        // default top
        getOverlayAlignmentFromSelf(alignSelf: style?.flexChild?.alignSelf) ??
        getOverlayAlignmentFromWrapper(
            alignItem: wrapperStyle?.container?.alignItems,
            justifyContent: wrapperStyle?.container?.justifyContent
        ) ?? .top
    }

    private func getOverlayAlignmentFromSelf(alignSelf: FlexAlignment?) -> Alignment? {
        switch alignSelf {
        case .flexStart:
            return .top
        case .flexEnd:
            return .bottom
        case .center, .stretch:
            return .center
        default:
            return nil
        }
    }

    private func getOverlayAlignmentFromWrapper(alignItem: FlexAlignment?,
                                                justifyContent: FlexJustification?) -> Alignment? {
        guard alignItem != nil || justifyContent != nil else { return nil }
        if let alignItem, let justifyContent {
            switch alignItem {
            case .center, .stretch:
                return getCenterAlignment(justifyContent)
            case .flexStart:
                return getTopAlignment(justifyContent)
            case .flexEnd:
                return getBottomAlignment(justifyContent)
            }
        } else if let justifyContent {
            return getCenterAlignment(justifyContent)
        } else if let alignItem {
            return getDefaultItemAlignment(alignItem)
        } else {
            return nil
        }
    }

    private func getCenterAlignment(_ justifyContent: FlexJustification) -> Alignment {
        switch justifyContent {
        case .center:
            return .center
        case .flexStart:
            return .leading
        case .flexEnd:
            return .trailing
        }
    }
    private func getTopAlignment(_ justifyContent: FlexJustification) -> Alignment {
        switch justifyContent {
        case .center:
            return .top
        case .flexStart:
            return .topLeading
        case .flexEnd:
            return .topTrailing
        }
    }
    private func getBottomAlignment(_ justifyContent: FlexJustification) -> Alignment {
        switch justifyContent {
        case .center:
            return .bottom
        case .flexStart:
            return .bottomLeading
        case .flexEnd:
            return .bottomTrailing
        }
    }
    private func getDefaultItemAlignment(_ alignItem: FlexAlignment) -> Alignment {
        switch alignItem {
        case .center, .stretch:
            return .center
        case .flexStart:
            return .top
        case .flexEnd:
            return .bottom
        }
    }

}
