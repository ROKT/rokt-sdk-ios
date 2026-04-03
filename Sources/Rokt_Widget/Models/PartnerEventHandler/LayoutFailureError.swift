import Foundation
enum LayoutFailureError: Error, Equatable {
    case layoutEmpty(pluginId: String?)
    case layoutTransformerError(pluginId: String?)
}
