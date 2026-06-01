import Foundation

enum BNFSeparator: String {
    case startDelimiter = "%^"
    case endDelimiter = "^%"
    case namespace = "."
    case alternative = "|"

    var charCount: Int { self.rawValue.count }
}
