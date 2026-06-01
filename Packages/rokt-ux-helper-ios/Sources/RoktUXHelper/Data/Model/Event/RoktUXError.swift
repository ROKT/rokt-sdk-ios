import Foundation

public enum RoktUXError: Error {
    case experienceResponseMapping
    case imageLoading(reason: String)
    case loadLayoutGeneric(sessionId: String)
    case loadLayoutEmpty(sessionId: String)
    case layoutTransform(pluginId: String?, sessionId: String)
    case unknown
}
