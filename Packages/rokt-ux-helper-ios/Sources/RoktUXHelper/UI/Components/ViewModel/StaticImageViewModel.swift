import Foundation
import DcuiSchema

@available(iOS 15, *)
class StaticImageViewModel: Hashable, Identifiable, BaseStyleAdaptive {

    let id: UUID = UUID()

    let url: StaticImageUrl?
    let alt: String?
    let stylingProperties: [BasicStateStylingBlock<BaseStyles>]?

    weak var layoutState: (any LayoutStateRepresenting)?

    var imageLoader: RoktUXImageLoader? {
        layoutState?.imageLoader
    }

    init(url: StaticImageUrl?,
         alt: String?,
         stylingProperties: [BasicStateStylingBlock<BaseStyles>]?,
         layoutState: (any LayoutStateRepresenting)?) {
        self.url = url
        self.alt = alt

        self.stylingProperties = stylingProperties
        self.layoutState = layoutState
    }
}
