import XCTest

// MARK: - Memory Leak Tracking

extension XCTestCase {
    func trackForMemoryLeaks(_ object: AnyObject, file: StaticString = #file, line: UInt = #line) {
        addTeardownBlock { [weak object] in
            XCTAssertNil(object, "Object was not deallocated. Check for memory leak.", file: file, line: line)
        }
    }
}

// MARK: - Data Shorthand

extension XCTestCase {
    func anyURLString() -> String {
        "https://some-partner-url.com"
    }

    func anyURL() -> URL {
        URL(string: anyURLString())!
    }

    func anyData() -> Data {
        do {
            return try JSONSerialization.data(withJSONObject: anyEncodable())
        } catch {
            // In test code, returning empty data is usually acceptable if serialization fails
            return Data()
        }
    }

    func anyEncodable() -> [String: String] {
        ["some-key": "some-value"]
    }

    func anyNSError() -> NSError {
        return NSError(domain: "some partner error", code: 0)
    }

    func anyHTTPURLResponse() -> HTTPURLResponse {
        return HTTPURLResponse(url: anyURL(), statusCode: 200, httpVersion: nil, headerFields: nil)!
    }

    func anyHTTPURLResponseWithError(statusCode: Int = 404) -> HTTPURLResponse {
        return HTTPURLResponse(url: anyURL(), statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }

    func nonHTTPURLResponse() -> URLResponse {
        return URLResponse(url: anyURL(), mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
    }
}
