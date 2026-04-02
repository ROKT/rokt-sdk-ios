import Foundation

/// Font model
class FontModel: NSObject {
    private static let fontNameKey = "fontName"
    private static let fontUrlKey = "fontUrl"
    private static let fontPostScriptNameKey = "fontPostScriptName"

    let name: String
    let url: String
    let postScriptName: String?

    init(name: String, url: String, postScriptName: String? = nil) {
        self.name = name
        self.url = url
        self.postScriptName = postScriptName
    }

    convenience init?(fontDict: [String: Any]) {
        if let fName = fontDict[Self.fontNameKey] as? String,
           let fUrl = fontDict[Self.fontUrlKey] as? String {
            self.init(
                name: fName,
                url: fUrl,
                postScriptName: fontDict[Self.fontPostScriptNameKey] as? String
            )
        } else {
            return nil
        }
    }
}
