import Foundation

enum RoktDownloadOptions: CaseIterable {
    case removePreviousFile
    case createIntermediateDirectories
}

// Protocol to hide implementation details
protocol HTTPClientAdapter {
    /// - Parameter timeout: seconds. Callers holding a millisecond-based config value, such as the
    ///   client timeout from init, must convert before calling.
    func updateTimeout(timeout: Double)

    @discardableResult
    func startRequestWith(
        urlAddress: String,
        method: RoktHTTPMethod,
        parameters: RoktHTTPParameters?,
        parameterArray: RoktHTTPParameterArray?,
        headers: RoktHTTPHeaders?,
        onRequestStart: (() -> Void)?,
        requestTimeout: TimeInterval?,
        completionQueue: DispatchQueue,
        completionHandler: ((RoktHTTPRequestResult) -> Void)?
    ) -> URLRequest?

    /// Builds the request now and returns the one call that sends it. The returned call creates the network task and
    /// resumes it; nothing is sent until it runs, and a caller that drops it sends nothing. A caller uses it to do the
    /// work that grows with the request — its URL, its headers and the encoding of its body — before a step it must
    /// keep short, such as a hand-off under a lock. A conformer that does not build a request ahead of time keeps the
    /// default, which defers its whole `startRequestWith` into the returned call.
    func prepareRequest(
        urlAddress: String,
        method: RoktHTTPMethod,
        parameters: RoktHTTPParameters?,
        parameterArray: RoktHTTPParameterArray?,
        headers: RoktHTTPHeaders?,
        onRequestStart: (() -> Void)?,
        requestTimeout: TimeInterval?,
        completionQueue: DispatchQueue,
        completionHandler: ((RoktHTTPRequestResult) -> Void)?
    ) -> () -> Void

    func downloadFile(
        source urlAddress: String,
        destinationURL: URL,
        options: [RoktDownloadOptions],
        parameters: RoktHTTPParameters?,
        headers: RoktHTTPHeaders?,
        requestTimeout: TimeInterval?,
        completionQueue: DispatchQueue,
        completionHandler: ((RoktDownloadResult) -> Void)?
    )
}

extension HTTPClientAdapter {
    func prepareRequest(
        urlAddress: String,
        method: RoktHTTPMethod,
        parameters: RoktHTTPParameters?,
        parameterArray: RoktHTTPParameterArray?,
        headers: RoktHTTPHeaders?,
        onRequestStart: (() -> Void)?,
        requestTimeout: TimeInterval?,
        completionQueue: DispatchQueue,
        completionHandler: ((RoktHTTPRequestResult) -> Void)?
    ) -> () -> Void {
        return {
            _ = self.startRequestWith(
                urlAddress: urlAddress,
                method: method,
                parameters: parameters,
                parameterArray: parameterArray,
                headers: headers,
                onRequestStart: onRequestStart,
                requestTimeout: requestTimeout,
                completionQueue: completionQueue,
                completionHandler: completionHandler
            )
        }
    }
}

internal final class RoktHTTPClient: HTTPClientAdapter {

    enum RoktDownloadError: Error {
        case downloadLocationError(RoktDownloadLocationError)
        case downloadFailed(error: Error)
    }

    enum RoktDownloadLocationError: Error {
        case temporaryURLMissing
        case targetDirectoryInvalid(error: Error)
    }

    enum RoktHTTPClientError: Error {
        case responseSerializationError(RoktResponseSerializationError)

        case requestInvalid

        case cannotCastToHTTPResponse

        case responseSerializationFailed(reason: RoktResponseSerializationError)

        case unacceptableStatusCode(code: Int)
    }

    enum RoktResponseSerializationError: Error {
        case inputDataMissing
        case serializationFailed(error: Error)
    }

    private let acceptableStatusCodes = Array(200..<300)
    private let emptyDataStatusCodes: Set<Int> = [204, 205]

    private(set) var session: URLSession = .shared
    // Serialises `session`, which `updateTimeout` reassigns on the request hot path.
    private let sessionLock = NSLock()
    private(set) var downloadSession: URLSession = .shared
    private(set) var encoders: [RoktHTTPParameterEncoder] = []

    /// How long a download may sit without receiving data before it is abandoned. This, rather
    /// than a cap on the total transfer, is what should fail a download: a large file on a slow
    /// connection is still making progress, whereas one receiving nothing is not.
    static let downloadIdleTimeoutSeconds: TimeInterval = 30

    /// Ceiling on an entire download. Deliberately far larger than the API client timeout: it
    /// exists to stop a pathological trickle running forever, not to bound a healthy transfer.
    static let downloadResourceTimeoutSeconds: TimeInterval = 300

    init(
        sessionConfiguration: URLSessionConfiguration = .default,
        encoders: [RoktHTTPParameterEncoder] = [RoktHTTPURLEncoder(), RoktHTTPBodyEncoder()]
    ) {
        let configuration = (sessionConfiguration.copy() as? URLSessionConfiguration) ?? sessionConfiguration
        Self.disableCookieHandling(on: configuration)
        self.session = URLSession(configuration: configuration)
        self.downloadSession = URLSession(
            configuration: Self.downloadConfiguration(from: configuration)
        )

        self.encoders = encoders
    }

    /// `timeoutIntervalForResource` caps a whole transfer rather than idle time, so applying
    /// the API client timeout to it cancels any download that cannot finish inside that
    /// budget no matter how healthy the connection is. Font files are orders of magnitude
    /// larger than API payloads, so downloads get their own session bounded by idle time.
    ///
    /// Both intervals are set explicitly rather than inherited: the incoming configuration is
    /// sized for API calls, so leaving either in place would silently reimpose an API-shaped
    /// budget on file transfers. Everything else is copied so injected protocol classes and
    /// cache policy still apply.
    private static func downloadConfiguration(
        from configuration: URLSessionConfiguration
    ) -> URLSessionConfiguration {
        let downloadConfiguration = (configuration.copy() as? URLSessionConfiguration) ?? configuration
        downloadConfiguration.timeoutIntervalForRequest = downloadIdleTimeoutSeconds
        downloadConfiguration.timeoutIntervalForResource = downloadResourceTimeoutSeconds
        disableCookieHandling(on: downloadConfiguration)

        return downloadConfiguration
    }

    // Match Android behaviour: the SDK does not store or send cookies.
    private static func disableCookieHandling(on configuration: URLSessionConfiguration) {
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.httpCookieAcceptPolicy = .never
    }

    /// Applies to API requests only. Downloads keep their own budget, since the client timeout
    /// is sized for small JSON payloads and would cancel large files mid-transfer.
    ///
    /// - Parameter timeout: seconds.
    func updateTimeout(timeout: Double) {
        sessionLock.lock()
        defer { sessionLock.unlock() }

        let currentConfiguration = session.configuration

        currentConfiguration.timeoutIntervalForRequest = timeout
        currentConfiguration.timeoutIntervalForResource = timeout
        Self.disableCookieHandling(on: currentConfiguration)

        self.session = URLSession(configuration: currentConfiguration)
    }

    // Runs `body` under the lock; callers create and resume the task inside, binding it
    // to a live session rather than a reference used after a concurrent swap.
    private func withSession<T>(_ body: (URLSession) -> T) -> T {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        return body(session)
    }

    @discardableResult
    func startRequestWith(
        urlAddress: String,
        method: RoktHTTPMethod,
        parameters: RoktHTTPParameters? = nil,
        parameterArray: RoktHTTPParameterArray? = nil,
        headers: RoktHTTPHeaders? = nil,
        onRequestStart: (() -> Void)? = nil,
        requestTimeout: TimeInterval? = nil,
        completionQueue: DispatchQueue = .main,
        completionHandler: ((RoktHTTPRequestResult) -> Void)? = nil
    ) -> URLRequest? {
        let request = createURLRequestWith(
            urlAddress: urlAddress,
            method: method,
            parameters: parameters,
            parameterArray: parameterArray,
            headers: headers,
            requestTimeout: requestTimeout
        )
        makeSend(
            request: request,
            onRequestStart: onRequestStart,
            completionQueue: completionQueue,
            completionHandler: completionHandler
        )()

        return request
    }

    /// Builds the request now — its URL, its query, its headers and the JSON encoding of its body — and returns the
    /// one call that sends it. The returned call runs `onRequestStart`, then creates the URLSession task and resumes
    /// it under the session lock; nothing is sent until it runs. A request that could not be built sends nothing and
    /// reports `requestInvalid` on the completion queue when the returned call runs. `startRequestWith` is this
    /// followed at once by the returned call, so both entries send the same bytes for the same inputs.
    func prepareRequest(
        urlAddress: String,
        method: RoktHTTPMethod,
        parameters: RoktHTTPParameters?,
        parameterArray: RoktHTTPParameterArray?,
        headers: RoktHTTPHeaders?,
        onRequestStart: (() -> Void)?,
        requestTimeout: TimeInterval?,
        completionQueue: DispatchQueue,
        completionHandler: ((RoktHTTPRequestResult) -> Void)?
    ) -> () -> Void {
        makeSend(
            request: createURLRequestWith(
                urlAddress: urlAddress,
                method: method,
                parameters: parameters,
                parameterArray: parameterArray,
                headers: headers,
                requestTimeout: requestTimeout
            ),
            onRequestStart: onRequestStart,
            completionQueue: completionQueue,
            completionHandler: completionHandler
        )
    }

    // The send for a request that is already built: `onRequestStart`, then the task's creation and resume under
    // `sessionLock`, so the task binds to the live session. Everything proportional to the request's size has already
    // run in `createURLRequestWith`; a caller that must keep a step short — a hand-off under a lock — runs only this
    // there. A request that could not be built reports `requestInvalid` on the completion queue instead of sending.
    private func makeSend(
        request: URLRequest?,
        onRequestStart: (() -> Void)?,
        completionQueue: DispatchQueue,
        completionHandler: ((RoktHTTPRequestResult) -> Void)?
    ) -> () -> Void {
        guard let request else {
            let requestResult = RoktHTTPRequestResult(
                httpURLResponse: nil,
                responseData: nil,
                responseError: nil,
                jsonSerialisedResponseData: .failure(RoktHTTPClientError.requestInvalid)
            )

            return { completionQueue.async { completionHandler?(requestResult) } }
        }

        return {
            onRequestStart?()
            self.withSession { session in
                session.dataTask(with: request) { [weak self] (data, response, error) in
                    guard let self else { return }

                    let anyJSONSerialisationResult = self.serializeAsJSON(
                        data: data,
                        response: response,
                        error: error
                    )

                    let requestResult = RoktHTTPRequestResult(
                        httpURLResponse: response as? HTTPURLResponse,
                        responseData: data,
                        responseError: error,
                        jsonSerialisedResponseData: anyJSONSerialisationResult
                    )

                    completionQueue.async { completionHandler?(requestResult) }
                }.resume()
            }
        }
    }

    private func createURLRequestWith(
        urlAddress: String,
        method: RoktHTTPMethod,
        parameters: RoktHTTPParameters? = nil,
        parameterArray: RoktHTTPParameterArray? = nil,
        headers: RoktHTTPHeaders? = nil,
        requestTimeout: TimeInterval? = nil
    ) -> URLRequest? {
        guard var components = URLComponents(string: urlAddress) else { return nil }

        if let urlEncoder = encoders.first(where: { $0.id == String(describing: RoktHTTPURLEncoder.self) }),
           let encodedComponents = urlEncoder.encode(
               parameterEncodable: components,
               parameters: parameters,
               parameterArray: parameterArray,
               httpMethod: method
           ) as? URLComponents {
            components = encodedComponents
        }

        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)

        request.httpMethod = method.asURLHTTPMethod

        if let customTimeout = requestTimeout {
            request.timeoutInterval = customTimeout
        }

        headers?.forEach { (headerKey, headerValue) in
            request.setValue(headerValue, forHTTPHeaderField: headerKey)
        }

        if let jsonBodyEncoder = encoders.first(where: { $0.id == String(describing: RoktHTTPBodyEncoder.self) }),
           let encodedRequest = jsonBodyEncoder.encode(
               parameterEncodable: request,
               parameters: parameters,
               parameterArray: parameterArray,
               httpMethod: method
           ) as? URLRequest {
            request = encodedRequest
        }

        // Session config already disables cookies; this keeps a replacement URLRequest
        // from the body encoder from restoring URLSession's default cookie handling.
        request.httpShouldHandleCookies = false

        return request
    }

    private func serializeAsJSON(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        options: JSONSerialization.ReadingOptions = .allowFragments
    ) -> Swift.Result<Any, Error> {
        guard error == nil else { return .failure(error!) }

        guard let response,
              let httpURLResponse = response as? HTTPURLResponse
        else { return .failure(RoktHTTPClientError.cannotCastToHTTPResponse) }

        if !acceptableStatusCodes.contains(httpURLResponse.statusCode) {
            return .failure(RoktHTTPClientError.unacceptableStatusCode(code: httpURLResponse.statusCode))
        }

        if emptyDataStatusCodes.contains(httpURLResponse.statusCode) {
            return .success(NSNull())
        }

        guard let data, !data.isEmpty
        else {
            return .failure(RoktHTTPClientError.responseSerializationFailed(reason: .inputDataMissing))
        }

        do {
            let anyJSON = try JSONSerialization.jsonObject(with: data, options: options)
            return .success(anyJSON)
        } catch {
            return .failure(RoktHTTPClientError.responseSerializationError(
                RoktHTTPClient.RoktResponseSerializationError.serializationFailed(error: error)
            ))
        }
    }

    deinit {
        downloadSession.finishTasksAndInvalidate()
    }
}

// MARK: - File download

extension RoktHTTPClient {
    func downloadFile(
        source urlAddress: String,
        destinationURL: URL,
        options: [RoktDownloadOptions] = RoktDownloadOptions.allCases,
        parameters: RoktHTTPParameters? = nil,
        headers: RoktHTTPHeaders? = nil,
        requestTimeout: TimeInterval? = nil,
        completionQueue: DispatchQueue = .main,
        completionHandler: ((RoktDownloadResult) -> Void)? = nil
    ) {

        func sendDownloadResultCallback(downloadResponse: URLResponse? = nil,
                                        downloadedFileLocalURL: URL? = nil,
                                        downloadError: Error? = nil) {
            completionQueue.async {
                completionHandler?(RoktDownloadResult(
                    httpURLResponse: downloadResponse as? HTTPURLResponse,
                    downloadedFileLocalURL: downloadedFileLocalURL,
                    downloadError: downloadError
                ))
            }
        }

        guard let downloadRequest = createURLRequestWith(
            urlAddress: urlAddress,
            method: .get,
            parameters: parameters,
            headers: headers,
            requestTimeout: requestTimeout
        ) else {

            sendDownloadResultCallback(downloadResponse: nil, downloadedFileLocalURL: nil,
                                       downloadError: RoktHTTPClientError.requestInvalid)
            return
        }

        downloadSession.downloadTask(with: downloadRequest) { [weak self] temporaryURL, downloadResponse, downloadError in
            guard let self else { return }

            if let downloadError {

                sendDownloadResultCallback(downloadResponse: downloadResponse, downloadedFileLocalURL: nil,
                                           downloadError: RoktDownloadError.downloadFailed(error: downloadError))

                return
            }

            if let downloadResponseStatusCode = (downloadResponse as? HTTPURLResponse)?.statusCode,
               !self.acceptableStatusCodes.contains(downloadResponseStatusCode) {

                sendDownloadResultCallback(
                    downloadResponse: downloadResponse, downloadedFileLocalURL: nil,
                    downloadError: RoktHTTPClientError.unacceptableStatusCode(code: downloadResponseStatusCode)
                )

                return
            }

            guard let temporaryURL else {

                sendDownloadResultCallback(
                    downloadResponse: downloadResponse, downloadedFileLocalURL: nil,
                    downloadError: RoktDownloadError.downloadLocationError(
                        RoktDownloadLocationError.temporaryURLMissing
                    )
                )

                return
            }

            saveFileToDestination(temporaryURL: temporaryURL,
                                  destinationURL: destinationURL,
                                  downloadResultCallback: sendDownloadResultCallback,
                                  downloadResponse: downloadResponse)
        }
        .resume()
    }

    private func saveFileToDestination(
        temporaryURL: URL,
        destinationURL: URL,
        options: [RoktDownloadOptions] = RoktDownloadOptions.allCases,
        downloadResultCallback: (URLResponse?, URL?, Error?) -> Void,
        downloadResponse: URLResponse?
    ) {
        do {
            if options.contains(.removePreviousFile), FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            if options.contains(.createIntermediateDirectories) {
                let directory = destinationURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }

            try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)

            downloadResultCallback(downloadResponse, destinationURL, nil)

        } catch {
            downloadResultCallback(downloadResponse, nil,
                                   RoktDownloadError.downloadLocationError(
                                       RoktDownloadLocationError.targetDirectoryInvalid(error: error)
                                   ))
        }
    }
}
