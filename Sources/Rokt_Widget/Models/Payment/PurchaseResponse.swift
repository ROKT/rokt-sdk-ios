import Foundation

struct PurchaseResponse: Decodable {
    let success: Bool
    let reason: String?
}
