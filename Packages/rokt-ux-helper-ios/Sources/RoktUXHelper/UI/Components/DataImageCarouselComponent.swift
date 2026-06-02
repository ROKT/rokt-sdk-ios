import SwiftUI
import Combine
import DcuiSchema

@available(iOS 15, *)
struct HSPageView<Content: View>: View {
    @Binding var page: Int
    let content: Content

    init(page: Binding<Int>, @ViewBuilder content: () -> Content) {
        self._page = page
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            _VariadicView.Tree(HSStackPager(width: geo.size.width, page: page), content: { content })
        }
    }

    struct HSStackPager: _VariadicView_UnaryViewRoot {
        let width: CGFloat
        let page: Int
        func body(children: _VariadicView.Children) -> some View {
            HStack(spacing: 0) {
                ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                    child.frame(width: width)
                }
            }
            .offset(x: -CGFloat(page) * width)
        }
    }
}

@available(iOS 15, *)
struct DataImageCarouselComponent: View {
    @SwiftUI.Environment(\.colorScheme) var colorScheme

    private var style: DataImageCarouselStyles? {
        switch styleState {
        case .hovered:
            model.stylingProperties?[safe: breakpointIndex]?.hovered
        case .pressed:
            model.stylingProperties?[safe: breakpointIndex]?.pressed
        case .disabled:
            model.stylingProperties?[safe: breakpointIndex]?.disabled
        default:
            model.defaultStyle?[safe: breakpointIndex]
        }
    }

    @EnvironmentObject var globalScreenSize: GlobalScreenSize
    @State var breakpointIndex = 0

    var dimensionStyle: DimensionStylingProperties? { style?.dimension }
    var flexStyle: FlexChildStylingProperties? { style?.flexChild }
    var borderStyle: BorderStylingProperties? { style?.border }
    var spacingStyle: SpacingStylingProperties? { style?.spacing }
    var backgroundStyle: BackgroundStylingProperties? { style?.background }
    var containerStyle: ContainerStylingProperties? { style?.container }

    let config: ComponentConfig
    let model: DataImageCarouselViewModel

    @Binding var parentWidth: CGFloat?
    @Binding var parentHeight: CGFloat?
    @Binding var styleState: StyleState
    @Binding var customStateMap: RoktUXCustomStateMap?

    init(
        config: ComponentConfig,
        model: DataImageCarouselViewModel,
        parentWidth: Binding<CGFloat?>,
        parentHeight: Binding<CGFloat?>,
        styleState: Binding<StyleState>,
        parentOverride: ComponentParentOverride?
    ) {
        self.config = config
        self.model = model
        self._parentWidth = parentWidth
        self._parentHeight = parentHeight
        self._styleState = styleState
        self.parentOverride = parentOverride

        _customStateMap = model.layoutState?
            .items[LayoutState.customStateMap] as? Binding<RoktUXCustomStateMap?> ?? .constant(nil)
    }

    let parentOverride: ComponentParentOverride?

    // Carousel specific states
    @State private var currentImage = 0
    @State private var page = 0
    @State private var isAutoScrolling = true
    @State private var opacities: [Double] = []
    @State private var availableWidth: CGFloat?
    @State private var availableHeight: CGFloat?

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

        if !model.images.isEmpty {
            // Initialize opacities array if needed
            ZStack(
                alignment: .init(
                    horizontal: horizontalAlignment.getHorizontalAlignment(),
                    vertical: verticalAlignment.getVerticalAlignment()
                )
            ) {
                switch model.transition {
                case let .slideInOut(duration):
                    imageView(for: model.images[0]).opacity(0.0)
                    HSPageView(page: $page) {
                        ForEach(0..<model.images.count, id: \.self) { index in
                            imageView(for: model.images[index]).tag(index)
                        }
                        imageView(for: model.images[0]).tag(model.images.count)
                    }
                    .disabled(true)
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .onReceive(model.$pageIndex.dropFirst()) { pageIndex in
                        DispatchQueue.main.async {
                            var realPageIndex = 0
                            if pageIndex == 0 {
                                realPageIndex = model.images.count
                            } else if pageIndex == 1 {
                                page = 0
                                realPageIndex = pageIndex
                            } else {
                                realPageIndex = pageIndex
                            }

                            withAnimation(.easeInOut(duration: duration/1000.0)) {
                                page = realPageIndex
                            }
                        }
                    }
                case let .fadeInOut(duration):
                    ForEach(0..<model.images.count, id: \.self) { index in
                        imageView(for: model.images[index])
                            .opacity(index < opacities.count ? opacities[index] : 0)
                    }
                    .onReceive(model.$currentProgress.dropFirst()) { currentProgress in
                        let newPosition = max(currentProgress - 1, 0)
                        if currentImage != newPosition {
                            advanceToNextImage(duration: duration)
                        }
                    }
                }

                if let indicatorViewModel = model.indicatorViewModel, model.requiresIndicator(colorScheme) {
                    VStack(
                        alignment: .center, spacing: 0
                    ) {
                        Spacer()
                        ImageCarouselIndicator(
                            config: config,
                            model: indicatorViewModel,
                            styleState: $styleState,
                            parentWidth: $availableWidth,
                            parentHeight: $availableHeight,
                            parentOverride: parentOverride
                        )
                        .onReceive(model.$currentProgress.dropFirst()) { currentProgress in
                            let positionKey = CustomStateIdentifiable(position: config.position, key: .imageCarouselPosition)
                            customStateMap?[positionKey] = currentProgress
                            let key = CustomStateIdentifiable(position: config.position, key: .imageCarouselKey(key: model.key))
                            customStateMap?[key] = currentProgress
                            model.layoutState?.publishStateChange()
                        }
                    }
                }
            }
            .applyLayoutModifier(
                verticalAlignmentProperty: verticalAlignment,
                horizontalAlignmentProperty: horizontalAlignment,
                spacing: spacingStyle,
                dimension: dimensionStyle,
                flex: flexStyle,
                border: borderStyle,
                background: backgroundStyle,
                parent: config.parent,
                parentWidth: $parentWidth,
                parentHeight: $parentHeight,
                parentOverride: parentOverride,
                defaultHeight: .wrapContent,
                defaultWidth: .wrapContent,
                expandsToContainerOnSelfAlign: false,
                imageLoader: model.imageLoader
            )
            .onChange(of: globalScreenSize.width) { newSize in
                DispatchQueue.main.async {
                    breakpointIndex = model.updateBreakpointIndex(for: newSize)
                }
            }
            .readSize(spacing: spacingStyle) { size in
                availableWidth = size.width
                availableHeight = size.height
            }
            .onLoad {
                // Initialize opacities array with first image visible
                if opacities.isEmpty {
                    opacities = Array(repeating: 0.0, count: model.images.count)
                    opacities[0] = 1.0
                }
                model.onAppear()
            }
            .onDisappear {
                model.onDisappear()
            }
        } else {
            EmptyView()
        }
    }

    private func imageView(for image: CreativeImage) -> some View {
        AsyncImageView(
            imageUrl: ThemeUrl(light: image.light ?? "", dark: image.dark ?? ""),
            scale: .fit,
            alt: image.accessibilityAltText,
            imageLoader: model.imageLoader,
            isImageValid: .constant(true)
        )
        .frame(maxWidth: .infinity)
        .aspectRatio(contentMode: .fit)
    }

    private func advanceToNextImage(duration: Double) {
        guard !model.images.isEmpty else { return }

        // Fade out current image
        withAnimation(.easeInOut(duration: duration/1000.0)) {
            opacities[currentImage] = 0.0
        }

        // Advance to next image
        currentImage = (currentImage + 1) % model.images.count

        // Fade in new image
        withAnimation(.easeInOut(duration: duration/1000.0)) {
            opacities[currentImage] = 1.0
        }
    }
}
