// periphery:ignore:all
import Foundation

extension Environment {
    // Mock reuses the prod host — the mock transport is swapped in so the URL is never hit.
    var gatewayBaseURL: String {
        switch self {
        case .Mock: return Environment.Prod.baseURL
        default: return baseURL
        }
    }
}
