import Foundation

struct ProcessedTimingsRequest: Codable, Hashable {
    // periphery:ignore - used implicitly by Hashable for uniqueness checking
    let pageInstanceGuid: String?
}
