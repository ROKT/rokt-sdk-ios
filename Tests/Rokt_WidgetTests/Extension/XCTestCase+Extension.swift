import XCTest

// MARK: - Polling

extension XCTestCase {
    func waitUntil(_ condition: @escaping () -> Bool, timeout: TimeInterval = 2) {
        let exp = expectation(description: "condition met")
        func check() {
            if condition() {
                exp.fulfill()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02, execute: check)
            }
        }
        check()
        wait(for: [exp], timeout: timeout)
    }
}

// MARK: - Document Directory

extension XCTestCase {
    /// Creates the document directory a test is about to read or write through.
    ///
    /// These tests run without a host app, so `NSHomeDirectory()` is the simulator's device data
    /// root rather than an app container. `Documents` is created there during boot rather than at
    /// install, so a suite that reaches it first finds no directory and every write into it fails -
    /// including the ones `-retry-tests-on-failure` retries, since nothing creates it in between.
    func ensureDocumentDirectoryExists() {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        try? FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
    }
}

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
