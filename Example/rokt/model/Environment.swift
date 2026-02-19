import Foundation
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
}
