import UIKit

internal enum Environment: Equatable {
    case Mock
    case Stage
    case Prod
    case ProdDemo
    case Local
    case custom(baseURL: String)

    var baseURL: String {
        switch self {
        case .Mock: return ""
        case .Stage: return "https://apps.stage.rokt.com"
        case .Prod: return "https://apps.rokt.com"
        case .ProdDemo: return "https://mobile-api-demo.rokt.com"
        case .Local: return "http://localhost:9011"
        case .custom(let url): return url
        }
    }
}

internal struct Configuration {
    lazy var environment: Environment = {

        if let configuration = Bundle.main.object(forInfoDictionaryKey: "Configuration") as? String {
            if configuration.contains("STAGE") {
                return Environment.Stage
            } else if configuration.contains("PRODDEMO") {
                return Environment.ProdDemo
            } else if configuration.contains("MOCK") {
                return Environment.Mock
            }
        }

        return Environment.Prod
    }()

    static func getEnvironment(_ environment: RoktEnvironment?) -> Environment {
        switch environment {
        case .Stage: return Environment.Stage
        case .Prod: return Environment.Prod
        case .ProdDemo: return Environment.ProdDemo
        case .Local: return Environment.Local
        default: return Environment.Mock
        }
    }
}
