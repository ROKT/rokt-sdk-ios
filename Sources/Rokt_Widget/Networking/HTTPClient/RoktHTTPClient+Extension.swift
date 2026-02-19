import Foundation

internal enum RoktHTTPMethod: String {
    case get
    case post

    var asURLHTTPMethod: String { rawValue.uppercased() }
}

internal typealias RoktHTTPHeaders = [String: String]
internal typealias RoktHTTPParameters = [String: Any]
internal typealias RoktHTTPParameterArray = [[String: Any]]

internal struct RoktHTTPRequestResult {
    let httpURLResponse: HTTPURLResponse?
    let responseData: Data?
    let responseError: Error?
    let jsonSerialisedResponseData: Swift.Result<Any, Error>
}

internal struct RoktDownloadResult {
    let httpURLResponse: HTTPURLResponse?
    let downloadedFileLocalURL: URL?
    let downloadError: Error?
}
