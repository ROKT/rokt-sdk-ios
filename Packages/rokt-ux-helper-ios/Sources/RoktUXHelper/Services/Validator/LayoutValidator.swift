import Foundation
struct LayoutValidator {

    static func isValidColor(_ hexString: String) -> Bool {
        // ARGB (32-bit), RGB (24-bit), RGB (12-bit)
        let regex = "^#([A-Fa-f0-9]{8}|[A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$"
        return hexString.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
    }

}
