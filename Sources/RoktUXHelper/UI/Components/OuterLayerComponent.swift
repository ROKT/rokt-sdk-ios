import SwiftUI
import DcuiSchema

@available(iOS 15, *)
struct OuterLayerComponent: View {
    @SwiftUI.Environment(\.colorScheme) var colorScheme
    let viewModel: RoktEmbeddedViewModel
    let style: StylingPropertiesModel?
    let onSizeChange: ((CGFloat) -> Void)?

    var containerStyle: ContainerStylingProperties? { style?.container }
    var dimensionStyle: DimensionStylingProperties? { style?.dimension }
    var flexStyle: FlexChildStylingProperties? { style?.flexChild }
    var borderStyle: BorderStylingProperties? { style?.border }
    var spacingStyle: SpacingStylingProperties? { style?.spacing }
    var backgroundStyle: BackgroundStylingProperties? { style?.background }

    let parent: ComponentParentType

    @Binding var parentWidth: CGFloat?
    @Binding var parentHeight: CGFloat?
    @State private var availableWidth: CGFloat?
    @State private var availableHeight: CGFloat?
    @State private var styleState: StyleState = .default
    @State var lastUpdatedHeight: CGFloat = 0

    var verticalAlignment: VerticalAlignmentProperty {
        containerStyle?.justifyContent?.asVerticalAlignmentProperty ?? .top
    }

    var horizontalAlignment: HorizontalAlignmentProperty {
        containerStyle?.alignItems?.asHorizontalAlignmentProperty ?? .start
    }

    init(
        layouts: [LayoutSchemaViewModel]?,
        style: StylingPropertiesModel?,
        layoutState: (any LayoutStateRepresenting)?,
        eventService: EventServicing?,
        parent: ComponentParentType = .root,
        parentWidth: Binding<CGFloat?>,
        parentHeight: Binding<CGFloat?>,
        onSizeChange: ((CGFloat) -> Void)? = nil
    ) {
        self.viewModel = RoktEmbeddedViewModel(layouts: layouts,
                                               eventService: eventService,
                                               layoutState: layoutState)
        self.style = style
        self.parent = parent
        _parentWidth = parentWidth
        _parentHeight = parentHeight
        self.onSizeChange = onSizeChange
    }

    var body: some View {
        if let layouts = viewModel.layouts {
            build(layouts: layouts)
                .applyLayoutModifier(
                    verticalAlignmentProperty: verticalAlignment,
                    horizontalAlignmentProperty: horizontalAlignment,
                    spacing: spacingStyle,
                    dimension: dimensionStyle,
                    flex: flexStyle,
                    border: borderStyle,
                    background: backgroundStyle,
                    container: containerStyle,
                    parent: parent,
                    parentWidth: $parentWidth,
                    parentHeight: $parentHeight,
                    parentOverride: nil,
                    defaultHeight: .fitHeight,
                    defaultWidth: .wrapContent,
                    imageLoader: viewModel.imageLoader
                )
                .readSize(spacing: spacingStyle) { size in
                    availableWidth = size.width
                    availableHeight = size.height
                    DispatchQueue.main.async {
                        notifyHeightChanged(size.height)
                    }
                }
                .onLoad {
                    viewModel.sendOnLoadEvents()
                }
                .onFirstTouch {
                    viewModel.sendSignalActivationEvent()
                }
                .onChange(of: colorScheme) { newColor in
                    viewModel.updateAttributedStrings(newColor)
                }
        }
    }

    private func build(layouts: [LayoutSchemaViewModel]) -> some View {
        VStack(spacing: 0) {
            ForEach(layouts, id: \.self) { child in
                LayoutSchemaComponent(config: ComponentConfig(parent: .column, position: nil),
                                      layout: child,
                                      parentWidth: $availableWidth,
                                      parentHeight: $availableHeight,
                                      styleState: $styleState,
                                      parentOverride: ComponentParentOverride(parentVerticalAlignment: nil,
                                                                              parentHorizontalAlignment: nil,
                                                                              parentBackgroundStyle: backgroundStyle,
                                                                              stretchChildren: nil))
            }
        }
    }

    func notifyHeightChanged(_ newHeight: CGFloat) {
        if lastUpdatedHeight != newHeight {
            onSizeChange?(newHeight)
            lastUpdatedHeight = newHeight
        }
    }
}

@available(iOS 15, *)
class GlobalScreenSize: ObservableObject, Equatable {
    @LazyPublished var width: CGFloat?
    @LazyPublished var height: CGFloat?
}
