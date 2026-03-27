import Foundation

private let fontNameKey = "fontName"
private let fontUrlKey = "fontUrl"
private let fontPostScriptNameKey = "fontPostScriptName"

/// Font model
class FontModel: NSObject {
    let name: String
    let url: String
    let postScriptName: String?

    init(name: String, url: String, postScriptName: String? = nil) {
        self.name = name
        self.url = url
        self.postScriptName = postScriptName
    }

    convenience init?(fontDict: [String: Any]) {
        if let fName = fontDict[fontNameKey] as? String,
           let fUrl = fontDict[fontUrlKey] as? String {
            self.init(
                name: fName,
                url: fUrl,
                postScriptName: fontDict[fontPostScriptNameKey] as? String
            )
        } else {
            return nil
        }
    }
}
