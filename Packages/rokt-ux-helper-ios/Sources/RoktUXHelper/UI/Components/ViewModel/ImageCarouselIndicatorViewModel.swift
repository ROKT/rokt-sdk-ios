import Foundation
import DcuiSchema

@available(iOS 15, *)
class ImageCarouselIndicatorViewModel:
    Hashable,
    Identifiable,
    ObservableObject,
    BaseStyleAdaptive {

    let id: UUID = UUID()

    private let positions: Int
    private let duration: Int32
    let stylingProperties: [BasicStateStylingBlock<BaseStyles>]?

    let indicatorStyle: [BasicStateStylingBlock<BaseStyles>]?
    let seenIndicatorStyle: [BasicStateStylingBlock<BaseStyles>]?
    let activeIndicatorStyle: [BasicStateStylingBlock<BaseStyles>]?
    let shouldDisplayProgress: Bool

    @Published var availableWidth: CGFloat?
    @Published var availableHeight: CGFloat?
    @Published var breakpointIndex: Int = 0
    @Published var styleState: StyleState = .default

    weak var layoutState: (any LayoutStateRepresenting)?
    var imageLoader: RoktUXImageLoader? {
        layoutState?.imageLoader
    }

    lazy var rowViewModels: [RowViewModel] = createRowViewModels()

    init(
        positions: Int,
        duration: Int32,
        stylingProperties: [BasicStateStylingBlock<DataImageCarouselIndicatorStyles>]?,
        indicatorStyle: [BasicStateStylingBlock<DataImageCarouselIndicatorStyles>]?,
        seenIndicatorStyle: [BasicStateStylingBlock<DataImageCarouselIndicatorStyles>]?,
        activeIndicatorStyle: [BasicStateStylingBlock<DataImageCarouselIndicatorStyles>]?,
        layoutState: (any LayoutStateRepresenting)?,
        shouldDisplayProgress: Bool
    ) {
        self.positions = positions
        self.duration = duration
        self.stylingProperties = stylingProperties?.mapToBaseStyles(BaseStyles.init)
        self.indicatorStyle = indicatorStyle?.mapToBaseStyles(BaseStyles.init)
        self.seenIndicatorStyle = seenIndicatorStyle?.mapToBaseStyles(BaseStyles.init)
        self.activeIndicatorStyle = activeIndicatorStyle?.mapToBaseStyles(BaseStyles.init)
        self.layoutState = layoutState
        self.shouldDisplayProgress = shouldDisplayProgress
    }

    private func createRowViewModels() -> [RowViewModel] {
        guard let activeStyle = activeIndicatorStyle?[safe: breakpointIndex] ?? activeIndicatorStyle?.first else {
            return []
        }

        let animatableStyle: AnimationStyle? = shouldDisplayProgress ? .init(
            duration: Double(duration)/1000.0,
            style: activeStyle.default
        ) : nil
        let activeStylingProperties: [BasicStateStylingBlock<BaseStyles>]? = [
            .init(
                default: BaseStyles(
                    background: indicatorStyle?[0].default.background,
                    border: activeStyle.default.border,
                    container: activeStyle.default.container,
                    dimension: activeStyle.default.dimension,
                    flexChild: activeStyle.default.flexChild,
                    spacing: activeStyle.default.spacing,
                    text: activeStyle.default.text
                ),
                pressed: nil,
                hovered: nil,
                focussed: nil,
                disabled: nil
            )
        ]

        let progressStyle: [BasicStateStylingBlock<BaseStyles>] = [
            .init(
                default: BaseStyles(
                    background: activeStyle.default.background,
                    container: nil,
                    dimension: .init(
                        minWidth: nil,
                        maxWidth: nil,
                        width: shouldDisplayProgress ? .fixed(0) : activeStyle.default.dimension?.width,
                        minHeight: nil,
                        maxHeight: nil,
                        height: activeStyle.default.dimension?.height,
                        rotateZ: nil
                    )
                ),
                pressed: nil,
                hovered: nil,
                focussed: nil,
                disabled: nil
            )
        ]

        return (0..<positions).map {
            ImageCarouselIndicatorItemViewModel(
                index: Int32($0 + 1),
                duration: duration,
                progressStyle: progressStyle,
                activeStyle: activeStylingProperties,
                animatableStyle: animatableStyle,
                indicatorStyle: indicatorStyle,
                seenStyle: seenIndicatorStyle,
                layoutState: layoutState,
                shouldDisplayProgress: shouldDisplayProgress
            )
        }
    }

    func shouldUpdate(_ size: CGSize) {
        if availableWidth != size.width {
            availableWidth = size.width
        }
        if availableHeight != size.height {
            availableHeight = size.height
        }
    }

    func shouldUpdateBreakpoint(_ width: CGFloat?) {
        let index = max(min(layoutState?.getGlobalBreakpointIndex(width) ?? 0,
                            (defaultStyle?.count ?? 1) - 1), 0)
        if index != breakpointIndex {
            breakpointIndex = index
        }
    }
}
