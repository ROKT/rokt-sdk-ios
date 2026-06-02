import Foundation
enum LayoutTransformerError: Error, Equatable {
    case InvalidColor(color: String)
    case InvalidMapping(line: Int = #line, function: String = #function)
    case InvalidSyntaxMapping(line: Int = #line, function: String = #function)
    case missingData
}
