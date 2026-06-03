// periphery:ignore:all - net-new v2 init configuration, not yet wired into the live path
import Foundation

internal enum TxnEnvironment: Equatable {
    case stage
    case prod
    case local
    case custom(baseURL: String)

    var gatewayBaseURL: String {
        switch self {
        case .stage: return "https://api.stage.rokt.com"
        case .prod: return "https://api.rokt.com"
        case .local: return "http://localhost:9011"
        case .custom(let baseURL): return baseURL
        }
    }
}

internal struct TxnConfiguration {
    lazy var environment: TxnEnvironment = {
        if let configuration = Bundle.main.object(forInfoDictionaryKey: "Configuration") as? String,
           configuration.contains("STAGE") {
            return .stage
        }
        return .prod
    }()

    // No v2 mock or demo host: ProdDemo and unspecified fall back to prod.
    static func getEnvironment(_ environment: RoktEnvironment?) -> TxnEnvironment {
        switch environment {
        case .Stage: return .stage
        case .Prod: return .prod
        case .Local: return .local
        case .ProdDemo: return .prod
        default: return .prod
        }
    }
}
