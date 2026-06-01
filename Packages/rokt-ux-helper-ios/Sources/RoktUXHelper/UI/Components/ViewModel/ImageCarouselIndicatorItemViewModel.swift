import Foundation
import DcuiSchema

fileprivate extension BaseStyles {
    static let wrapContentStyle = BaseStyles(
        dimension: .init(
            minWidth: nil,
            maxWidth: nil,
            width: .fit(.wrapContent),
            minHeight: nil,
            maxHeight: nil,
            height: .fit(.wrapContent),
            rotateZ: nil
        )
    )
}

@available(iOS 15, *)
class ImageCarouselIndicatorItemViewModel: RowViewModel {
    init(
        index: Int32,
        duration: Int32,
        progressStyle: [BasicStateStylingBlock<BaseStyles>],
        activeStyle: [BasicStateStylingBlock<BaseStyles>]?,
        animatableStyle: AnimationStyle?,
        indicatorStyle: [BasicStateStylingBlock<BaseStyles>]?,
        seenStyle: [BasicStateStylingBlock<BaseStyles>]?,
        layoutState: (any LayoutStateRepresenting)?,
        shouldDisplayProgress: Bool
    ) {
        func whenNode(
            index: Int32,
            condition: OrderableWhenCondition,
            style: [BasicStateStylingBlock<BaseStyles>]?,
            layoutState: (any LayoutStateRepresenting)?,
            child: RowViewModel? = nil
        ) -> LayoutSchemaViewModel {

            var children = [LayoutSchemaViewModel]()
            if let child {
                children.append(.row(child))
            }

            let row = RowViewModel(
                children: children,
                stylingProperties: style,
                animatableStyle: nil,
                accessibilityGrouped: false,
                layoutState: layoutState,
                predicates: nil,
                globalBreakPoints: nil,
                offers: []
            )

            return .when(WhenViewModel(
                children: [.row(row)],
                predicates: [.customState(.init(key: .imageCarouselPosition, condition: condition, value: index))],
                transition: nil,
                offers: [],
                globalBreakPoints: nil,
                layoutState: layoutState
            ))
        }

        let progressViewModel = RowViewModel(
            children: nil,
            stylingProperties: progressStyle,
            animatableStyle: animatableStyle,
            accessibilityGrouped: false,
            layoutState: layoutState,
            predicates: nil,
            globalBreakPoints: nil,
            offers: []
        )

        // imageCarouselPosition is the current progress; "seen" means current progress > this index.
        let whenSeen = whenNode(index: index, condition: .isAbove, style: seenStyle, layoutState: layoutState)
        let whenActive = whenNode(
            index: index,
            condition: .is,
            style: activeStyle,
            layoutState: layoutState,
            child: progressViewModel
        )
        // "not seen" means current progress < this index.
        let whenNotSeen = whenNode(index: index, condition: .isBelow, style: indicatorStyle, layoutState: layoutState)

        super.init(
            children: [whenSeen, whenActive, whenNotSeen],
            stylingProperties: [
                .init(
                    default: BaseStyles(
                        background: BackgroundStylingProperties(backgroundColor: nil, backgroundImage: nil),
                        border: nil,
                        container: nil,
                        dimension: BaseStyles.wrapContentStyle.dimension,
                        flexChild: nil,
                        spacing: nil,
                        text: nil
                    ),
                    pressed: nil,
                    hovered: nil,
                    focussed: nil,
                    disabled: nil
                )
            ],
            animatableStyle: nil,
            accessibilityGrouped: false,
            layoutState: layoutState,
            predicates: nil,
            globalBreakPoints: nil,
            offers: []
        )
    }
}
