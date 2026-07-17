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
}
