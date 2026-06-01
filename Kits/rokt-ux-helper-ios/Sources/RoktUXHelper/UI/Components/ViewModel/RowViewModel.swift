import Foundation
import DcuiSchema
import Combine

@available(iOS 15, *)
class RowViewModel: Identifiable, Hashable, BaseStyleAdaptive, PredicateHandling, ObservableObject {
    let id: UUID = UUID()
    var children: [LayoutSchemaViewModel]?
    let stylingProperties: [BasicStateStylingBlock<BaseStyles>]?
    let accessibilityGrouped: Bool
    weak var layoutState: (any LayoutStateRepresenting)?
    let animatableStyle: AnimationStyle?
    let predicates: [WhenPredicate]?
    let globalBreakPoints: BreakPoint?
    let offers: [OfferModel?]
    var width: CGFloat = 0
    var cancellable: AnyCancellable?
    var componentConfig: ComponentConfig?

    @Published var animate: Bool = false

    var imageLoader: RoktUXImageLoader? {
        layoutState?.imageLoader
    }

    var defaultStyle: [BaseStyles]? {
        stylingProperties?.map(\.default)
    }

    init(children: [LayoutSchemaViewModel]?,
         stylingProperties: [BasicStateStylingBlock<BaseStyles>]?,
         animatableStyle: AnimationStyle?,
         accessibilityGrouped: Bool,
         layoutState: (any LayoutStateRepresenting)?,
         predicates: [WhenPredicate]?,
         globalBreakPoints: BreakPoint?,
         offers: [OfferModel?]) {
        self.children = children
        self.stylingProperties = stylingProperties
        self.animatableStyle = animatableStyle
        self.accessibilityGrouped = accessibilityGrouped
        self.layoutState = layoutState
        self.predicates = predicates
        self.globalBreakPoints = globalBreakPoints
        self.offers = offers

        animate = shouldApply() && !animatableStyle.isNil
        cancellable = layoutState?.itemsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                animate = shouldApply() && !animatableStyle.isNil
            }
    }

    deinit {
        cancellable?.cancel()
        cancellable = nil
    }
}
