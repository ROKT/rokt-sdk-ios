import XCTest
@testable import Rokt_Widget

final class RoktHTTPClientTests: XCTestCase {
    override func setUp() {
        super.setUp()

        FileManager.createDirectoryAt(path: FileManager.testDirectoryURL.path)

        RoktHTTPUrlProtocolStub.startInterceptingRequests()
    }

    override func tearDown() {
        FileManager.removeAllItemsInsideDirectory(url: FileManager.testDirectoryURL)

        RoktHTTPUrlProtocolStub.stopInterceptingRequests()

        super.tearDown()
    }

    func test_updateTimeout_changesIntervalForRequestAndIntervalForResource() {
        let configuration = URLSessionConfiguration.default

        let sut = RoktHTTPClient(sessionConfiguration: configuration)

        // default value is 60 seconds - https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1408259-timeoutintervalforrequest
        XCTAssertEqual(sut.session.configuration.timeoutIntervalForRequest, 60.0, accuracy: 0.1)

        // default is 7 days - https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1408153-timeoutintervalforresource
        XCTAssertEqual(sut.session.configuration.timeoutIntervalForResource, 7 * 24 * 60 * 60, accuracy: 0.1)

        sut.updateTimeout(timeout: 123)

        XCTAssertEqual(sut.session.configuration.timeoutIntervalForRequest, 123, accuracy: 0.1)
        XCTAssertEqual(sut.session.configuration.timeoutIntervalForResource, 123, accuracy: 0.1)
    }

    func test_startRequest_performsGETRequestWithURL() {
        let url = anyURL()
        let exp = expectation(description: "Wait for request")

        RoktHTTPUrlProtocolStub.observeRequests { request in
            XCTAssertEqual(request.url, url)
            XCTAssertEqual(request.httpMethod, "GET")
            exp.fulfill()
        }

        makeSUT().startRequestWith(urlAddress: anyURLString(), method: .get)

        wait(for: [exp], timeout: 0.1)
    }

    func test_startRequest_addsDefaultHeaders() {
        let exp = expectation(description: "Wait for request")

        RoktHTTPUrlProtocolStub.observeRequests { request in
            XCTAssertEqual(request.allHTTPHeaderFields?.count, 2)

            XCTAssertEqual(request.allHTTPHeaderFields?["header-key-1"], "header-value-1")
            XCTAssertEqual(request.allHTTPHeaderFields?["header-key-2"], "header-value-2")

            exp.fulfill()
        }

        makeSUT().startRequestWith(
            urlAddress: anyURLString(),
            method: .get,
            headers: ["header-key-1": "header-value-1", "header-key-2": "header-value-2"]
        )

        wait(for: [exp], timeout: 0.1)
    }

    func test_startRequest_withParameters_encodesParameters() {
        let exp = expectation(description: "Wait for request")

        RoktHTTPUrlProtocolStub.observeRequests { request in
            XCTAssertEqual(
                request.url?.absoluteString,
                "https://some-partner-url.com?boolean-key=false&double-key=123.456&int-key=123&string-key=string-val&string-key-with-plus=string%2Bval&string-key-with-space=string%20val"
            )

            exp.fulfill()
        }

        makeSUT().startRequestWith(
            urlAddress: anyURLString(),
            method: .get,
            parameters: [
                "string-key": "string-val",
                "string-key-with-plus": "string+val",
                "string-key-with-space": "string val",
                "int-key": 123,
                "double-key": 123.456,
                "boolean-key": false
            ]
        )

        wait(for: [exp], timeout: 0.1)
    }

    func test_getFromURL_failsOnRequestError() {
        let requestError = anyNSError()

        let receivedError = startRequestWithErrorFor(data: nil, response: nil, error: requestError)

        XCTAssertEqual((receivedError as NSError?)?.code, requestError.code)
        XCTAssertEqual((receivedError as NSError?)?.domain, requestError.domain)
    }

    func test_getFromURL_failsOnAllInvalidRepresentationCases() {
        // Use a smaller set of test cases to reduce test duration and console output
        struct TestCase {
            let data: Data?
            let response: URLResponse?
            let error: Error?
            let description: String
        }

        let testCases = [
            TestCase(data: nil, response: nil, error: nil, description: "nil data, nil response, nil error"),
            TestCase(
                data: nil,
                response: nonHTTPURLResponse(),
                error: nil,
                description: "nil data, non-HTTP response, nil error"
            ),
            TestCase(data: anyData(), response: nil, error: nil, description: "data, nil response, nil error"),
            TestCase(
                data: nil,
                response: anyHTTPURLResponse(),
                error: anyNSError(),
                description: "nil data, HTTP response, error"
            )
        ]

        for testCase in testCases {
            let error = startRequestWithErrorFor(
                data: testCase.data,
                response: testCase.response,
                error: testCase.error
            )

            XCTAssertNotNil(error, "Should get error for case: \(testCase.description)")
        }
    }

    func test_getFromURL_succeedsOnHTTPURLResponseWithData() {
        let data = anyData()
        let response = anyHTTPURLResponse()

        let receivedValues = startRequestWithValuesFor(data: data, response: response, error: nil)

        XCTAssertEqual(receivedValues.data, data)
        XCTAssertEqual(receivedValues.response?.url, response.url)
        XCTAssertEqual(receivedValues.response?.statusCode, response.statusCode)
    }

    func test_getFromURL_failsOnInvalidStatusCodes() throws {
        try assertRequestFailsOnInvalidStatusCode(invalidStatusCode: 300)
        try assertRequestFailsOnInvalidStatusCode(invalidStatusCode: 400)
        try assertRequestFailsOnInvalidStatusCode(invalidStatusCode: 401)
        try assertRequestFailsOnInvalidStatusCode(invalidStatusCode: 404)
        try assertRequestFailsOnInvalidStatusCode(invalidStatusCode: 500)
        try assertRequestFailsOnInvalidStatusCode(invalidStatusCode: 503)
        try assertRequestFailsOnInvalidStatusCode(invalidStatusCode: 504)
    }

    func test_getFromURL_withCorrectStatusCodeAndMissingData_shouldTriggerSerializationError() throws {
        let responseWithInvalidStatusCode = HTTPURLResponse(
            url: anyURL(),
            statusCode: 200,
            httpVersion: "HTTP/2",
            headerFields: nil
        )

        let receivedError = try XCTUnwrap(startRequestWithErrorFor(
            data: nil,
            response: responseWithInvalidStatusCode,
            error: nil
        ))

        guard let roktError = receivedError as? RoktHTTPClient.RoktHTTPClientError
        else {
            XCTFail("could not cast to a localised Rokt error")
            return
        }

        switch roktError {
        case let .responseSerializationFailed(reason: serialisationFailureReason):
            XCTAssertEqual(
                serialisationFailureReason.localizedDescription,
                RoktHTTPClient.RoktResponseSerializationError.inputDataMissing.localizedDescription
            )
        default:
            XCTFail("did not detect a serialisation error")
        }
    }

    func test_post_withParameters_addsParametersToHTTPBody() {
        let exp = expectation(description: "Wait for request")

        let bodyParams = [
            "email": "some@email.com",
            "mobile": "+61111222333",
            "french": "français",
            "japanese": "日本語",
            "arabic": "العربية",
            "emoji": "😃"
        ]

        RoktHTTPUrlProtocolStub.observeRequests { request in
            if let httpBody = request.bodyStreamAsJSON(), let httpBodyDictionary = httpBody as? [String: String] {
                XCTAssertEqual(httpBodyDictionary.count, bodyParams.count)

                XCTAssertEqual(httpBodyDictionary["email"], bodyParams["email"])
                XCTAssertEqual(httpBodyDictionary["mobile"], bodyParams["mobile"])
                XCTAssertEqual(httpBodyDictionary["french"], bodyParams["french"])
                XCTAssertEqual(httpBodyDictionary["japanese"], bodyParams["japanese"])
                XCTAssertEqual(httpBodyDictionary["arabic"], bodyParams["arabic"])
                XCTAssertEqual(httpBodyDictionary["emoji"], bodyParams["emoji"])
            } else {
                XCTFail("HTTP body does not exist")
            }

            exp.fulfill()
        }

        makeSUT().startRequestWith(
            urlAddress: anyURLString(),
            method: .post,
            parameters: bodyParams
        )

        wait(for: [exp], timeout: 0.1)
    }

    private func assertRequestFailsOnInvalidStatusCode(invalidStatusCode: Int) throws {
        let responseWithInvalidStatusCode = HTTPURLResponse(
            url: anyURL(),
            statusCode: invalidStatusCode,
            httpVersion: "HTTP/2",
            headerFields: nil
        )

        let receivedError = try XCTUnwrap(startRequestWithErrorFor(
            data: nil,
            response: responseWithInvalidStatusCode,
            error: nil
        ))

        guard let roktError = receivedError as? RoktHTTPClient.RoktHTTPClientError
        else {
            XCTFail("could not cast to a localised Rokt error")
            return
        }

        switch roktError {
        case let .unacceptableStatusCode(code: receivedStatusCode):
            XCTAssertEqual(invalidStatusCode, receivedStatusCode)
        default:
            XCTFail("did not detect an invalid status code")
        }
    }

    // MARK: - File Download

    func test_downloadFile_savesDownloadedFileToLocalDestination() throws {
        let data = anyData()
        let response = anyHTTPURLResponse()
        let destinationURL = FileManager.temporaryFileURL()

        let receivedValues = startDownloadWithResultFor(
            destinationURL: destinationURL,
            data: data,
            response: response,
            error: nil
        )

        XCTAssertEqual(receivedValues.httpURLResponse?.url, response.url)
        XCTAssertEqual(receivedValues.httpURLResponse?.statusCode, response.statusCode)
        XCTAssertNil(receivedValues.downloadError)

        let downloadedFileLocalURL = try XCTUnwrap(receivedValues.downloadedFileLocalURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: downloadedFileLocalURL.path))

        if let data = try? Data(contentsOf: downloadedFileLocalURL) {
            XCTAssertGreaterThan(data.count, 0)
        } else {
            XCTFail("downloaded file does not exist at target destination")
        }
    }

    func test_downloadFile_doesNotDownloadFileOnInvalidStatusCode() throws {
        let data = anyData()
        let response = anyHTTPURLResponseWithError()
        let destinationURL = FileManager.temporaryFileURL()

        let receivedValues = startDownloadWithResultFor(
            destinationURL: destinationURL,
            data: data,
            response: response,
            error: nil
        )

        XCTAssertNil(receivedValues.downloadedFileLocalURL)

        let downloadError = try XCTUnwrap(receivedValues.downloadError)

        guard let roktError = downloadError as? RoktHTTPClient.RoktHTTPClientError
        else {
            XCTFail("could not cast to a localised Rokt error")
            return
        }

        switch roktError {
        case let .unacceptableStatusCode(code: receivedStatusCode):
            XCTAssertEqual(404, receivedStatusCode)
        default:
            XCTFail("did not detect an invalid status code")
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: destinationURL.path))
        XCTAssertNil(try? Data(contentsOf: destinationURL))
    }

    func test_downloadFile_doesNotDownloadFileOnError() throws {
        let data = anyData()
        let response = anyHTTPURLResponse()
        let error = anyNSError()
        let destinationURL = FileManager.temporaryFileURL()

        let receivedValues = startDownloadWithResultFor(
            destinationURL: destinationURL,
            data: data,
            response: response,
            error: error
        )

        XCTAssertNil(receivedValues.downloadedFileLocalURL)

        let downloadError = try XCTUnwrap(receivedValues.downloadError)

        guard let roktError = downloadError as? RoktHTTPClient.RoktDownloadError,
              case let .downloadFailed(error: someDownloadError) = roktError
        else {
            XCTFail("could not cast to a localised Rokt error")
            return
        }

        XCTAssertEqual((someDownloadError as NSError).code, error.code)
        XCTAssertEqual((someDownloadError as NSError).domain, error.domain)

        XCTAssertFalse(FileManager.default.fileExists(atPath: destinationURL.path))
        XCTAssertNil(try? Data(contentsOf: destinationURL))
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #file, line: UInt = #line) -> RoktHTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RoktHTTPUrlProtocolStub.self]

        let sut = RoktHTTPClient(sessionConfiguration: configuration)

        trackForMemoryLeaks(sut, file: file, line: line)

        return sut
    }

    private func startRequestWithValuesFor(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        file: StaticString = #file,
        line: UInt = #line
    ) -> (data: Data?, response: HTTPURLResponse?) {
        let result = startRequestWithResultFor(data: data, response: response, error: error, file: file, line: line)

        switch result.jsonSerialisedResponseData {
        case .failure(let error):
            XCTFail("Expected success, got \(error) instead", file: file, line: line)
        default:
            break
        }

        return (result.responseData, result.httpURLResponse)
    }

    private func startRequestWithErrorFor(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Error? {
        let result = startRequestWithResultFor(data: data, response: response, error: error, file: file, line: line)

        switch result.jsonSerialisedResponseData {
        case let .failure(error):
            return error
        default:
            XCTFail("Expected failure, got \(result) instead", file: file, line: line)
            return nil
        }
    }

    private func startRequestWithResultFor(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        file: StaticString = #file,
        line: UInt = #line
    ) -> RoktHTTPRequestResult {
        RoktHTTPUrlProtocolStub.stub(data: data, response: response, error: error)
        let sut = makeSUT(file: file, line: line)
        let exp = expectation(description: "Wait for completion")

        var receivedResult: RoktHTTPRequestResult!
        sut.startRequestWith(urlAddress: anyURLString(), method: .get) { result in
            receivedResult = result
            exp.fulfill()
        }

        // Increase timeout for tests that are timing out
        wait(for: [exp], timeout: 5.0)
        return receivedResult
    }

    private func startDownloadWithResultFor(
        destinationURL: URL,
        data: Data?,
        response: URLResponse?,
        error: Error?,
        file: StaticString = #file,
        line: UInt = #line
    ) -> RoktDownloadResult {
        RoktHTTPUrlProtocolStub.stub(data: data, response: response, error: error)
        let sut = makeSUT(file: file, line: line)
        let exp = expectation(description: "Wait for completion")

        var receivedResult: RoktDownloadResult!
        sut.downloadFile(source: anyURLString(), destinationURL: destinationURL) { downloadResult in
            receivedResult = downloadResult
            exp.fulfill()
        }

        // Increase timeout for tests that are timing out
        wait(for: [exp], timeout: 5.0)
        return receivedResult
    }
}
