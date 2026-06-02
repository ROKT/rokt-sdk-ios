import Foundation

@available(iOS 13, *)
struct StyleSelfModel: Decodable, Hashable {
    let `self`: [StatePseudoTypes<StylingPropertiesModel>]
}
