import Foundation
import Rokt_Widget

enum Environment: String, CaseIterable {
    case Stage
    case Prod
    case ProdDemo
    case Local

    static var names: [String] {
        return Environment.allCases.map { $0.rawValue }
    }

    static var all: [Environment] {
        return Environment.allCases
    }

    var roktEnvironment: RoktEnvironment {
        switch self {
        case .Stage: return .Stage
        case .Prod: return .Prod
        case .ProdDemo: return .ProdDemo
        case .Local: return .Local
        }
    }
}
