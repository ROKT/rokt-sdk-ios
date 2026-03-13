import Foundation

enum RoktDownloadOptions: CaseIterable {
    case removePreviousFile
    case createIntermediateDirectories
}

// Protocol to hide implementation details
protocol HTTPClientAdapter {
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
    private(set) var downloadSession: URLSession = .shared
    private(set) var encoders: [RoktHTTPParameterEncoder] = []

    init(
        sessionConfiguration: URLSessionConfiguration = .default,
        encoders: [RoktHTTPParameterEncoder] = [RoktHTTPURLEncoder(), RoktHTTPBodyEncoder()]
    ) {
        self.session = URLSession(configuration: sessionConfiguration)
        self.downloadSession = URLSession(configuration: sessionConfiguration)

        self.encoders = encoders
    }

    func updateTimeout(timeout: Double) {
        let currentConfiguration = session.configuration

        currentConfiguration.timeoutIntervalForRequest = timeout
        currentConfiguration.timeoutIntervalForResource = timeout

        self.session = URLSession(configuration: currentConfiguration)
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
        guard let request = createURLRequestWith(
            urlAddress: urlAddress,
            method: method,
            parameters: parameters,
            parameterArray: parameterArray,
            headers: headers,
            requestTimeout: requestTimeout
        ) else {
            let requestResult = RoktHTTPRequestResult(
                httpURLResponse: nil,
                responseData: nil,
                responseError: nil,
                jsonSerialisedResponseData: .failure(RoktHTTPClientError.requestInvalid)
            )

            completionQueue.async { completionHandler?(requestResult) }

            return nil
        }

        onRequestStart?()
        let task = session.dataTask(with: request) { [weak self] (data, response, error) in
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
        }

        task.resume()

        return request
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

        session.downloadTask(with: downloadRequest) { [weak self] temporaryURL, downloadResponse, downloadError in
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
