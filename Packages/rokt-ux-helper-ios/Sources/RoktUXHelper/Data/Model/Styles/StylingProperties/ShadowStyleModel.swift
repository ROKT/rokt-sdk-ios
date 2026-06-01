import Foundation

@available(iOS 13, *)
struct ShadowStyleModel: Decodable, Hashable {
    let offsetX: Float?
    let offsetY: Float?
    let color: String?
    let blurRadius: Float?
}
