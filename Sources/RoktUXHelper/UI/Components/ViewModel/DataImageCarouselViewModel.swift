import Foundation
import DcuiSchema
import SwiftUI

@available(iOS 15, *)
class DataImageCarouselViewModel: Hashable, Identifiable, ObservableObject, ScreenSizeAdaptive {
    enum Transition {
        case slideInOut(Double)
        case fadeInOut(Double)
    }

    let id: UUID = UUID()
    let key: String
    let images: [CreativeImage]
    let duration: Int32
    let stylingProperties: [BasicStateStylingBlock<DataImageCarouselStyles>]?
    let transition: Transition

    weak var layoutState: (any LayoutStateRepresenting)?

    @Published var currentProgress: Int = 1
    @Published var pageIndex: Int = 0

    private var timer: Timer?

    let indicatorViewModel: ImageCarouselIndicatorViewModel?

    var imageLoader: RoktUXImageLoader? {
        layoutState?.imageLoader
    }

    var defaultStyle: [DataImageCarouselStyles]? {
        stylingProperties?.map(\.default)
    }

    init(key: String,
         images: [CreativeImage],
         duration: Int32,
         ownStyle: [BasicStateStylingBlock<DataImageCarouselStyles>]?,
         indicatorViewModel: ImageCarouselIndicatorViewModel?,
         layoutState: (any LayoutStateRepresenting)?,
         transition: Transition) {
        self.key = key
        self.images = images
        self.duration = duration
        stylingProperties = ownStyle
        self.indicatorViewModel = indicatorViewModel
        self.layoutState = layoutState
        self.transition = transition
    }

    func onAppear() {
        guard images.count > 1 && duration > 0 else { return }
        /// currentProgress = 0 is needed to reset the customStateMap image carousel position to 0
        /// so views can render its initial state without animations
        currentProgress = 0
        /// short delay needed for views to render initial state without animations
        /// and for customStateMap to be initialized in Distributions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            timer?.invalidate()
            currentProgress = 1
            timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(duration)/1000.0, repeats: true) { [weak self] timer in
                guard let self, timer.isValid else { return }
                incrementStateMap()
            }
        }
    }

    func onDisappear() {
        /// short delay incase appear and disappear are called the same time in landscape
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            timer?.invalidate()
        }
    }

    func requiresIndicator(_ colorScheme: ColorScheme) -> Bool {
        images.filter {
            ($0.light?.isEmpty == false && colorScheme == .light) ||
            ($0.dark?.isEmpty == false && colorScheme == .dark)
        }.count > 1
    }

    private func incrementStateMap() {
        currentProgress = max((currentProgress + 1) % (images.count + 1), 1)
        pageIndex = (pageIndex + 1) % images.count
    }
}
