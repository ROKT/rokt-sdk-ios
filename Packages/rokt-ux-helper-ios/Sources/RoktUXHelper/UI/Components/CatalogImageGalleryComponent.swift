import SwiftUI
import DcuiSchema

// MARK: - GalleryGestureView

/// UIKit gesture layer that disambiguates horizontal pan from vertical scroll,
/// allowing the gallery swipe to coexist with a parent ScrollView(.vertical).
struct GalleryGestureView: UIViewRepresentable {
    var onTap: (CGPoint) -> Void
    var onPanChanged: ((CGFloat) -> Void)?
    var onPanEnded: ((CGFloat, CGFloat) -> Void)?

    func makeUIView(context: Context) -> UIView {
        let view = UIView()

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)

        return view
    }

    func updateUIView(_: UIView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.onPanChanged = onPanChanged
        context.coordinator.onPanEnded = onPanEnded
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap, onPanChanged: onPanChanged, onPanEnded: onPanEnded)
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onTap: (CGPoint) -> Void
        var onPanChanged: ((CGFloat) -> Void)?
        var onPanEnded: ((CGFloat, CGFloat) -> Void)?
        private var lockedAxis: GalleryPanAxis?

        init(
            onTap: @escaping (CGPoint) -> Void,
            onPanChanged: ((CGFloat) -> Void)?,
            onPanEnded: ((CGFloat, CGFloat) -> Void)?
        ) {
            self.onTap = onTap
            self.onPanChanged = onPanChanged
            self.onPanEnded = onPanEnded
        }

        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            let location = sender.location(in: sender.view)
            onTap(location)
        }

        @objc func handlePan(_ sender: UIPanGestureRecognizer) {
            let translation = sender.translation(in: sender.view)
            let velocity = sender.velocity(in: sender.view)
            if lockedAxis == nil {
                lockedAxis = GallerySwipePolicy.lockedAxis(translation: translation, velocity: velocity)
            }

            switch sender.state {
            case .changed:
                guard lockedAxis == .horizontal else { return }
                onPanChanged?(translation.x)
            case .ended, .cancelled, .failed:
                defer { lockedAxis = nil }
                guard lockedAxis == .horizontal else { return }
                onPanEnded?(translation.x, velocity.x)
            default:
                break
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            let translation = pan.translation(in: pan.view)
            let velocity = pan.velocity(in: pan.view)
            lockedAxis = GallerySwipePolicy.lockedAxis(translation: translation, velocity: velocity)
            return lockedAxis == .horizontal
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer
        ) -> Bool {
            guard gestureRecognizer is UIPanGestureRecognizer else { return true }
            return lockedAxis != .horizontal
        }
    }
}

// MARK: - GallerySwipePolicy

enum GalleryPanAxis: Equatable {
    case horizontal
    case vertical
}

enum GallerySwipeDirection: Equatable {
    case backward
    case forward
}

struct GallerySwipeResolution: Equatable {
    let page: Int
    let direction: GallerySwipeDirection?
}

enum GallerySwipePolicy {
    private static let thresholdRatio: CGFloat = 0.22
    private static let minimumThreshold: CGFloat = 44
    private static let maximumThreshold: CGFloat = 90
    private static let flickVelocity: CGFloat = 500
    private static let horizontalDominanceRatio: CGFloat = 1
    private static let axisLockMinimumDistance: CGFloat = 8

    static func shouldBeginPan(translation: CGPoint = .zero, velocity: CGPoint) -> Bool {
        lockedAxis(translation: translation, velocity: velocity) == .horizontal
    }

    static func lockedAxis(translation: CGPoint = .zero, velocity: CGPoint) -> GalleryPanAxis? {
        if let axis = axis(horizontal: abs(translation.x), vertical: abs(translation.y), minimum: axisLockMinimumDistance) {
            return axis
        }

        return axis(horizontal: abs(velocity.x), vertical: abs(velocity.y), minimum: 0)
    }

    private static func axis(horizontal: CGFloat, vertical: CGFloat, minimum: CGFloat) -> GalleryPanAxis? {
        guard max(horizontal, vertical) > minimum else { return nil }
        return horizontal > vertical * horizontalDominanceRatio ? .horizontal : .vertical
    }

    static func threshold(for width: CGFloat) -> CGFloat {
        min(max(max(width, 0) * thresholdRatio, minimumThreshold), maximumThreshold)
    }

    static func targetPage(
        currentPage: Int,
        pages: Int,
        width: CGFloat,
        translation: CGFloat,
        velocity: CGFloat
    ) -> GallerySwipeResolution {
        guard pages > 0 else {
            return GallerySwipeResolution(page: 0, direction: nil)
        }

        let currentPage = max(min(currentPage, pages - 1), 0)
        guard let direction = direction(width: width, translation: translation, velocity: velocity) else {
            return GallerySwipeResolution(page: currentPage, direction: nil)
        }

        let nextPage = switch direction {
        case .forward:
            min(currentPage + 1, pages - 1)
        case .backward:
            max(currentPage - 1, 0)
        }

        return GallerySwipeResolution(page: nextPage, direction: direction)
    }

    private static func direction(width: CGFloat, translation: CGFloat, velocity: CGFloat) -> GallerySwipeDirection? {
        if abs(translation) >= threshold(for: width) {
            return translation < 0 ? .forward : .backward
        }

        if abs(velocity) >= flickVelocity {
            return velocity < 0 ? .forward : .backward
        }

        return nil
    }
}

// MARK: - CatalogHSPageView

/// Horizontal pager that tracks drag offset for interactive swipe animation.
struct CatalogHSPageView<Content: View>: View {
    @Binding var page: Int
    let pages: Int
    let content: Content
    let onSwipe: ((Bool) -> Void)?
    let onTap: ((Bool) -> Void)?
    @State private var dragOffset: CGFloat = 0

    init(
        page: Binding<Int>,
        pages: Int,
        onSwipe: ((Bool) -> Void)? = nil,
        onTap: ((Bool) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        _page = page
        self.pages = pages
        self.onSwipe = onSwipe
        self.onTap = onTap
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            _VariadicView.Tree(
                CatalogHSStackPager(width: geo.size.width, page: page, dragOffset: dragOffset),
                content: { content }
            )
            .animation(.easeOut(duration: 0.25), value: page)
            .animation(.easeOut(duration: 0.25), value: dragOffset)

            GalleryGestureView(
                onTap: { point in
                    let isForward = point.x >= geo.size.width/2
                    if isForward {
                        page = min(page + 1, pages - 1)
                    } else {
                        page = max(page - 1, 0)
                    }
                    onTap?(isForward)
                },
                onPanChanged: { translation in
                    dragOffset = translation
                },
                onPanEnded: { translation, velocity in
                    let resolution = GallerySwipePolicy.targetPage(
                        currentPage: page,
                        pages: pages,
                        width: geo.size.width,
                        translation: translation,
                        velocity: velocity
                    )

                    if let direction = resolution.direction {
                        onSwipe?(direction == .forward)
                    }

                    dragOffset = 0
                    page = resolution.page
                }
            )
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
        }
    }

    struct CatalogHSStackPager: _VariadicView_UnaryViewRoot {
        let width: CGFloat
        let page: Int
        let dragOffset: CGFloat

        func body(children: _VariadicView.Children) -> some View {
            HStack(spacing: 0) {
                ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                    child.frame(width: width)
                }
            }
            .offset(x: -CGFloat(page) * width + dragOffset)
        }
    }
}

// MARK: - CatalogImageGalleryComponent

struct CatalogImageGalleryComponent: View {
    @SwiftUI.Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var globalScreenSize: GlobalScreenSize
    @ObservedObject var model: CatalogImageGalleryViewModel

    let config: ComponentConfig

    @Binding var parentWidth: CGFloat?
    @Binding var parentHeight: CGFloat?
    @Binding var styleState: StyleState

    let parentOverride: ComponentParentOverride?

    @State private var breakpointIndex: Int = 0
    @State private var frameChangeIndex: Int = 0
    @State private var page: Int = 0
    @State private var previousPage: Int = 0
    @State private var isUpdatingFromSelectedIndex = false
    @State private var isUpdatingFromSwipe = false
    @State private var availableWidth: CGFloat?
    @State private var availableHeight: CGFloat?

    private var style: CatalogImageGalleryStyles? {
        model.defaultStyle?[safe: breakpointIndex]
    }

    private var containerStyle: ContainerStylingProperties? { style?.container }
    private var dimensionStyle: DimensionStylingProperties? { style?.dimension }
    private var flexStyle: FlexChildStylingProperties? { style?.flexChild }
    private var borderStyle: BorderStylingProperties? { style?.border }
    private var spacingStyle: SpacingStylingProperties? { style?.spacing }
    private var backgroundStyle: BackgroundStylingProperties? { style?.background }

    private var passableBackgroundStyle: BackgroundStylingProperties? {
        backgroundStyle ?? parentOverride?.parentBackgroundStyle
    }

    private var verticalAlignment: VerticalAlignmentProperty {
        if let justifyContent = containerStyle?.justifyContent?.asVerticalAlignmentProperty {
            return justifyContent
        } else if let parentAlign = parentOverride?.parentVerticalAlignment?.asVerticalAlignmentProperty {
            return parentAlign
        } else {
            return .top
        }
    }

    private var horizontalAlignment: HorizontalAlignmentProperty {
        if let alignItems = containerStyle?.alignItems?.asHorizontalAlignmentProperty {
            return alignItems
        } else if let parentAlign = parentOverride?.parentHorizontalAlignment?.asHorizontalAlignmentProperty {
            return parentAlign
        } else {
            return .start
        }
    }

    var body: some View {
        VStack(
            alignment: columnPerpendicularAxisAlignment(alignItems: containerStyle?.alignItems),
            spacing: CGFloat(containerStyle?.gap ?? 0)
        ) {
            mainImageArea
        }
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.a11yLabel ?? "")
    }

    // MARK: - Main Image Area

    private var mainImageArea: some View {
        let overlayAlignment = indicatorOverlayAlignment(for: breakpointIndex)

        return ZStack {
            imageViewComponent(for: model.images[0]).opacity(0.0)
            CatalogHSPageView(
                page: $page,
                pages: model.images.count,
                onSwipe: { isForward in
                    isUpdatingFromSwipe = true
                    if isForward {
                        model.goForward()
                        model.handleSwipeForward()
                    } else {
                        model.goBackward()
                        model.handleSwipeBackward()
                    }
                },
                onTap: { isForward in
                    if isForward {
                        model.handleNavButtonForward()
                    } else {
                        model.handleNavButtonBackward()
                    }
                },
                content: {
                    ForEach(0..<model.images.count, id: \.self) { index in
                        imageViewComponent(for: model.images[index])
                    }
                }
            )
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .overlay { navigationButtonOverlay }
        .overlay(alignment: overlayAlignment) {
            indicatorOverlay(alignment: overlayAlignment)
        }
        .readSize(spacing: nil) { size in
            availableWidth = size.width
            availableHeight = size.height
        }
        .onChange(of: page) { newValue in
            previousPage = page
            model.selectedIndex = newValue
            isUpdatingFromSelectedIndex = false
            isUpdatingFromSwipe = false
        }
        .onChange(of: model.selectedIndex) { newIndex in
            guard page != newIndex else { return }
            previousPage = page
            isUpdatingFromSelectedIndex = true
            page = newIndex
        }
    }

    @State private var imageStyleState: StyleState = .default

    private func imageViewComponent(for viewModel: DataImageViewModel) -> some View {
        DataImageViewComponent(
            config: config.updateParent(.column),
            model: viewModel,
            parentWidth: $availableWidth,
            parentHeight: $availableHeight,
            styleState: $imageStyleState,
            parentOverride: ComponentParentOverride(
                parentVerticalAlignment: .center,
                parentHorizontalAlignment: .center,
                parentBackgroundStyle: passableBackgroundStyle,
                stretchChildren: false
            ),
            expandsToContainerOnSelfAlign: false
        )
    }

    // MARK: - Navigation Buttons

    private var controlButtonStyle: CatalogImageGalleryStyles? {
        model.controlButtonStyles?[safe: breakpointIndex]?.default
    }

    @ViewBuilder
    private var navigationButtonOverlay: some View {
        if model.backwardImage != nil || model.forwardImage != nil {
            HStack {
                if model.canGoBackward, let backwardImage = model.backwardImage {
                    navButton(themedImage: backwardImage) {
                        model.goBackward()
                        model.handleNavButtonBackward()
                    }
                }
                Spacer()
                if model.canGoForward, let forwardImage = model.forwardImage {
                    navButton(themedImage: forwardImage) {
                        model.goForward()
                        model.handleNavButtonForward()
                    }
                }
            }
            .padding(.horizontal, 8)
        }
    }

    @ViewBuilder
    private func navButton(
        themedImage: CatalogImageGalleryThemedImageUrl,
        action: @escaping () -> Void
    ) -> some View {
        let btnStyle = controlButtonStyle
        let bgColor: Color = btnStyle?.background?.backgroundColor.flatMap {
            Color(hex: colorScheme == .dark ? ($0.dark ?? $0.light) : $0.light)
        } ?? Color.black.opacity(0.5)
        let cornerRadius = CGFloat(btnStyle?.border?.borderRadius ?? 4)
        let iconSize = CGFloat(btnStyle?.text?.fontSize ?? 16)
        let paddingFrame = FrameAlignmentProperty.getFrameAlignment(btnStyle?.spacing?.padding)

        Button(action: action) {
            AsyncImageView(
                imageUrl: ThemeUrl(light: themedImage.light, dark: themedImage.dark),
                scale: .fit,
                alt: nil,
                imageLoader: model.imageLoader,
                isImageValid: .constant(true)
            )
            .frame(width: iconSize, height: iconSize)
            .padding(EdgeInsets(
                top: paddingFrame.top,
                leading: paddingFrame.left,
                bottom: paddingFrame.bottom,
                trailing: paddingFrame.right
            ))
            .background(bgColor)
            .cornerRadius(cornerRadius)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Indicator Overlay

    private func indicatorOverlayAlignment(for breakpointIndex: Int) -> Alignment {
        guard let alignSelf = model.indicatorAlignSelf(for: breakpointIndex) else {
            return .bottom
        }
        let vertical = alignSelf.asVerticalAlignment.asVerticalType ?? .bottom
        return Alignment(horizontal: .center, vertical: vertical)
    }

    @ViewBuilder
    private func indicatorOverlay(alignment: Alignment) -> some View {
        if model.showIndicators,
           let containerViewModel = model.indicatorContainerViewModel(for: breakpointIndex) {
            RowComponent(
                config: config,
                model: containerViewModel,
                parentWidth: $availableWidth,
                parentHeight: $availableHeight,
                styleState: .constant(.default),
                parentOverride: ComponentParentOverride(
                    parentVerticalAlignment: alignment.asVerticalType ?? .center,
                    parentHorizontalAlignment: alignment.asHorizontalType ?? .center,
                    parentBackgroundStyle: passableBackgroundStyle,
                    stretchChildren: false
                )
            )
            .overlay {
                indicatorTapTargets
            }
        }
    }

    @ViewBuilder
    private var indicatorTapTargets: some View {
        HStack(spacing: 0) {
            ForEach(0..<model.images.count, id: \.self) { index in
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        model.selectImage(at: index)
                        model.handleIndicatorTap()
                    }
            }
        }
    }
}
