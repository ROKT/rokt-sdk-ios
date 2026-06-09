// periphery:ignore:all - net-new v2 init configuration, not yet wired into the live path
import Foundation

internal enum TxnEnvironment: Equatable {
    case stage
    case prod
    case local
    case custom(baseURL: String)

    var gatewayBaseURL: String {
        switch self {
        case .stage: return "https://apps.stage.rokt.com"
        case .prod: return "https://apps.rokt.com"
        case .local: return "http://localhost:9011"
        case .custom(let baseURL): return baseURL
        }
    }
}

internal struct TxnConfiguration {
    // Maps the live config.environment onto the v2 gateway. Mock reuses prod (the mock
    // path swaps the transport, not the host); ProdDemo has no v2 host and reuses prod.
    static func getEnvironment(_ environment: Environment) -> TxnEnvironment {
        switch environment {
        case .Stage: return .stage
        case .Prod, .ProdDemo, .Mock: return .prod
        case .Local: return .local
        case .custom(let baseURL): return .custom(baseURL: baseURL)
        }
    }
}
