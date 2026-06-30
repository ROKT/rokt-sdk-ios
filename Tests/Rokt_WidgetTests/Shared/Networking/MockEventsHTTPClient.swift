import XCTest
@testable import Rokt_Widget

final class MockEventsHTTPClient: HTTPClientAdapter {
    enum Response {
        case success(status: Int, data: Data)
        case status(Int)
        case transport(Error)
    }

    var results: [Response] = []
    private(set) var callCount = 0
    private(set) var capturedHeaders: [RoktHTTPHeaders] = []

    func updateTimeout(timeout: Double) {}

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
    ) -> URLRequest? {
        capturedHeaders.append(headers ?? [:])
        let response = results.isEmpty
            ? .success(status: 202, data: Data(#"{ "event_ids": ["event-1"] }"#.utf8))
            : results[min(callCount, results.count - 1)]
        callCount += 1

        let url = URL(string: urlAddress) ?? URL(string: "https://apps.rokt.com")!
        let result: RoktHTTPRequestResult
        switch response {
        case .success(let status, let data):
            result = RoktHTTPRequestResult(
                httpURLResponse: HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil),
                responseData: data,
                responseError: nil,
                jsonSerialisedResponseData: .success(NSNull())
            )
        case .status(let code):
            result = RoktHTTPRequestResult(
                httpURLResponse: HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil),
                responseData: nil,
                responseError: nil,
                jsonSerialisedResponseData: .success(NSNull())
            )
        case .transport(let error):
            result = RoktHTTPRequestResult(
                httpURLResponse: nil,
                responseData: nil,
                responseError: error,
                jsonSerialisedResponseData: .failure(error)
            )
        }

        completionQueue.async { completionHandler?(result) }
        return nil
    }

    func downloadFile(
        source urlAddress: String,
        destinationURL: URL,
        options: [RoktDownloadOptions],
        parameters: RoktHTTPParameters?,
        headers: RoktHTTPHeaders?,
        requestTimeout: TimeInterval?,
        completionQueue: DispatchQueue,
        completionHandler: ((RoktDownloadResult) -> Void)?
    ) {}
}
