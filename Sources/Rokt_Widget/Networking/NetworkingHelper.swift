import UIKit

typealias ResponseHeaders = [AnyHashable: Any]

/// Networking helper class that makes HTTP requests
class NetworkingHelper {
    static let shared = NetworkingHelper()

    internal var httpClient: HTTPClientAdapter!
    internal var mParticleKitDetails: MParticleKitDetails?

    private init() {
        self.httpClient = createHTTPClient()
    }

    private func createHTTPClient(timeout: Double = 7) -> RoktHTTPClient {
        let configuration = URLSessionConfiguration.default

        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

        return RoktHTTPClient(sessionConfiguration: configuration)
    }

    class func updateTimeout(timeout: Double) {
        shared.httpClient.updateTimeout(timeout: timeout)
    }

    class func updateMParticleKitDetails(mParticleKitDetails: MParticleKitDetails) {
        shared.mParticleKitDetails = mParticleKitDetails
    }

    class func performPost(url: String,
                           body: [String: Any]?,
                           headers: [String: String]? = nil,
                           extraErrorCheck: Bool = false,
                           onRequestStart: (() -> Void)? = nil,
                           success: ((NSDictionary, Data?, ResponseHeaders?) -> Void)? = nil,
                           failure: ((Error, Int?, String) -> Void)? = nil,
                           retryCount: Int = 0) {
        guard let resolvedClient = shared.httpClient as? RoktHTTPClient else { return }

        resolvedClient.startRequestWith(
            urlAddress: url,
            method: .post,
            parameters: body,
            parameterArray: nil,
            headers: getCommonHeaders(headers),
            onRequestStart: onRequestStart,
            completionHandler: { requestResult in
                processHTTPRequestResult(httpResult: requestResult,
                                         success: success) { error, errorCode, errorReponse in
                    if retriableResponse(
                        error: error,
                        code: errorCode,
                        extraErrorCheck: extraErrorCheck
                    ) && retryCount < kMaxRetries {
                        performPost(url: url,
                                    body: body,
                                    headers: headers,
                                    extraErrorCheck: extraErrorCheck,
                                    onRequestStart: onRequestStart,
                                    success: success,
                                    failure: failure,
                                    retryCount: retryCount + 1)
                    } else {
                        failure?(error, errorCode, errorReponse)
                    }
                }
            }
        )
    }

    class func performPost(urlString: String,
                           bodyArray: [[String: Any]]?,
                           headers: [String: String]? = nil,
                           extraErrorCheck: Bool = false,
                           onRequestStart: (() -> Void)? = nil,
                           success: ((NSDictionary, Data?, ResponseHeaders?) -> Void)? = nil,
                           failure: ((Error, Int?, String) -> Void)? = nil,
                           retryCount: Int = 0) {
        guard let resolvedClient = shared.httpClient as? RoktHTTPClient else { return }

        resolvedClient.startRequestWith(
            urlAddress: urlString,
            method: .post,
            parameters: nil,
            parameterArray: bodyArray,
            headers: getCommonHeaders(headers),
            onRequestStart: onRequestStart
        ) { requestResult in
            processHTTPRequestResult(httpResult: requestResult, success: success) { error, errorCode, errorReponse in
                if retriableResponse(
                    error: error,
                    code: errorCode,
                    extraErrorCheck: extraErrorCheck
                ) && retryCount < kMaxRetries {
                    performPost(urlString: urlString,
                                bodyArray: bodyArray,
                                headers: headers,
                                extraErrorCheck: extraErrorCheck,
                                onRequestStart: onRequestStart,
                                success: success,
                                failure: failure,
                                retryCount: retryCount + 1)
                } else {
                    failure?(error, errorCode, errorReponse)
                }
            }
        }
    }

    class func performGet(
        url: String,
        params: [String: Any]?,
        headers: [String: String]? = nil,
        extraErrorCheck: Bool = false,
        success: ((NSDictionary, Data?, ResponseHeaders?) -> Void)? = nil,
        failure: ((Error, Int?, String) -> Void)? = nil,
        retryCount: Int = 0
    ) {
        guard let resolvedClient = shared.httpClient as? RoktHTTPClient else { return }

        resolvedClient.startRequestWith(
            urlAddress: url,
            method: .get,
            parameters: params,
            parameterArray: nil,
            headers: getCommonHeaders(headers),
            completionHandler: { requestResult in
                processHTTPRequestResult(httpResult: requestResult,
                                         success: success) { error, errorCode, errorReponse in
                    if retriableResponse(
                        error: error,
                        code: errorCode,
                        extraErrorCheck: extraErrorCheck
                    ) && retryCount < kMaxRetries {
                        performGet(url: url,
                                   params: params,
                                   headers: headers,
                                   extraErrorCheck: extraErrorCheck,
                                   success: success,
                                   failure: failure,
                                   retryCount: retryCount + 1)
                    } else {
                        failure?(error, errorCode, errorReponse)
                    }
                }
            }
        )
    }

    class internal func retriableResponse(error: Error, code: Int?, extraErrorCheck: Bool = false) -> Bool {
        if error._code == NSURLErrorTimedOut {
            return true
        }

        if isRetryableStatusCode(code) {
            return true
        }

        if extraErrorCheck && (error._code == NSURLErrorNetworkConnectionLost ||
                                error._code == NSURLErrorCannotFindHost ||
                                error._code == NSURLErrorCannotConnectToHost ||
                                error._code == NSURLErrorNotConnectedToInternet ||
                                error._code == NSURLErrorDNSLookupFailed ||
                                error._code == NSURLErrorResourceUnavailable) {
            return true
        }

        return false
    }

    class func isRetryableStatusCode(_ code: Int?) -> Bool {
        guard let c = code, let statusCode = HTTPStatusCode(rawValue: c) else {
            return false
        }

        switch statusCode {
        case .internalServerError, .badGateway, .serverNotAvailable:
            return true
        default:
            return false
        }
    }

    class internal func getCommonHeaders(_ headers: [String: String]?) -> [String: String] {
        let kOSType = "iOS"

        var headersDict = [String: String]()
        if let existingHeaders = headers {
            for (key, value) in existingHeaders {
                headersDict.updateValue(value, forKey: key)
            }
        }

        if let mParticleKitDetails = shared.mParticleKitDetails {
            headersDict.updateValue(mParticleKitDetails.sdkVersion, forKey: RoktHeaderKeys.mParticleSdkVersion)
            headersDict.updateValue(mParticleKitDetails.kitVersion, forKey: RoktHeaderKeys.mParticleKitVersion)
        }

        headersDict.updateValue(HTTPHeader.Value.applicationJSON, forKey: HTTPHeader.accept)
        headersDict.updateValue(HTTPHeader.Value.applicationJSON, forKey: HTTPHeader.contentType)
        headersDict.updateValue(kLibraryVersion, forKey: RoktHeaderKeys.sdkVersion)
        headersDict.updateValue(kOSType, forKey: RoktHeaderKeys.osType)
        headersDict.updateValue(UIDevice.current.systemVersion, forKey: RoktHeaderKeys.osVersion)
        headersDict.updateValue(UIDevice.modelName, forKey: RoktHeaderKeys.deviceModel)
        headersDict.updateValue(Bundle.main.bundleIdentifier!, forKey: RoktHeaderKeys.packageName)
        headersDict.updateValue(Locale.current.identifier, forKey: RoktHeaderKeys.uiLocale)

        if let version = Bundle.main.infoDictionary?[kBundleShort] as? String {
            headersDict.updateValue(version, forKey: RoktHeaderKeys.packageVersion)
        }

        return headersDict
    }

    // Gets the response dictionary from the response and calls the appropiate callback
    class private func processHTTPRequestResult(
        httpResult: RoktHTTPRequestResult,
        success: ((NSDictionary, Data?, (ResponseHeaders?)) -> Void)?,
        failure: ((Error, Int?, String) -> Void)?
    ) {
        switch httpResult.jsonSerialisedResponseData {
        case .success(let resultAny):
            var dict = [:] as NSDictionary

            if let responseDict = resultAny as? NSDictionary {
                dict = responseDict
            } else if let array = resultAny as? NSArray {
                dict = [kArrayResponseKey: array]
            }

            success?(dict, httpResult.responseData, httpResult.httpURLResponse?.allHeaderFields)
        case .failure(let error):
            if let statusCode = httpResult.httpURLResponse?.statusCode {
                if statusCode == NSURLErrorNotConnectedToInternet {
                    RoktLogger.shared.verbose(StringHelper.localizedStringFor(kNetworkErrorKey, comment: kNetworkErrorComment))
                    failure?(error, statusCode, kNetworkErrorComment)
                    return
                } else if statusCode == HTTPStatusCode.unauthorized.rawValue {
                    RoktLogger.shared.verbose(StringHelper.localizedStringFor(kUnauthorizedKey, comment: kUnauthorizedComment))
                    failure?(error, statusCode, kUnauthorizedComment)
                    return
                }
            }

            RoktLogger.shared.verbose(httpResult.httpURLResponse?.description
                    ?? StringHelper.localizedStringFor(kApiErrorKey, comment: kApiErrorC))
            RoktLogger.shared.verbose(error.localizedDescription)

            var responseString: String?

            if let responseData = httpResult.responseData {
                responseString = String(data: responseData, encoding: String.Encoding.utf8)
                if responseString == "" {
                    responseString = kEmptyResponse
                }

                let errorString = error.localizedDescription
                let apiResponseString = StringHelper.localizedStringFor(kApiResponseKey, comment: kApiResponseComment)
                let status = "\(apiResponseString) \(errorString) \(responseString ?? "")"

                RoktLogger.shared.verbose(status)
            }
            failure?(error, httpResult.httpURLResponse?.statusCode, responseString ?? kNoResponse)
        }
    }
}

// MARK: - File download

extension NetworkingHelper {
    func downloadFile(
        source urlAddress: String,
        destinationURL: URL,
        options: [RoktDownloadOptions] = RoktDownloadOptions.allCases,
        parameters: RoktHTTPParameters? = nil,
        headers: RoktHTTPHeaders? = nil,
        requestTimeout: TimeInterval? = nil,
        completionHandler: ((RoktDownloadResult) -> Void)?
    ) {
        guard let resolvedClient = httpClient as? RoktHTTPClient else { return }

        resolvedClient.downloadFile(
            source: urlAddress,
            destinationURL: destinationURL,
            options: options,
            parameters: parameters,
            headers: headers,
            requestTimeout: requestTimeout,
            completionHandler: completionHandler
        )
    }
}
