import Foundation
import SwiftUI
import DcuiSchema
import Combine

@available(iOS 15, *)
class WhenViewModel: Identifiable, Hashable, PredicateHandling, ObservableObject {

    let id: UUID = UUID()

    var children: [LayoutSchemaViewModel]?
    let predicates: [WhenPredicate]?
    let transition: WhenTransition?
    let offers: [OfferModel?]
    let globalBreakPoints: BreakPoint?
    weak var layoutState: (any LayoutStateRepresenting)?
    var componentConfig: ComponentConfig?
    var width: CGFloat = 0
    var cancellable: AnyCancellable?
    @Published var animate: Bool = false

    init(children: [LayoutSchemaViewModel]? = nil,
         predicates: [WhenPredicate]?,
         transition: WhenTransition?,
         offers: [OfferModel?],
         globalBreakPoints: BreakPoint?,
         layoutState: (any LayoutStateRepresenting)?) {
        self.children = children
        self.predicates = predicates
        self.transition = transition
        self.offers = offers
        self.globalBreakPoints = globalBreakPoints
        self.layoutState = layoutState

        cancellable = layoutState?.itemsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                animate = shouldApply() && predicates?.isEmpty == false
            }
    }

    var fadeInDuration: Double {
        transition?.inTransition.map { transitions in
            transitions.compactMap {
                if case let .fadeIn(settings) = $0 {
                    return Double(settings.duration)/1000
                }
                return nil
            }
        }?.first ?? 0
    }

    var fadeOutDuration: Double {
        transition?.outTransition.map { transitions in
            transitions.compactMap {
                if case let .fadeOut(settings) = $0 {
                    return Double(settings.duration)/1000
                }
                return nil
            }
        }?.first ?? 0
    }

    deinit {
        cancellable?.cancel()
        cancellable = nil
    }
}
