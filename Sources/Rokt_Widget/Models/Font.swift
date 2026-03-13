import Foundation

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
        if let fName = fontDict[BE_FONT_NAME_KEY] as? String,
           let fUrl = fontDict[BE_FONT_URL_KEY] as? String {
            self.init(
                name: fName,
                url: fUrl,
                postScriptName: fontDict[BE_FONT_POSTSCRIPT_NAME_KEY] as? String
            )
        } else {
            return nil
        }
    }
}
