import XCTest
@testable import RoktUXHelper

class RoktUXConfigTests: XCTestCase {

    func testDefaultConfig() {
        let config = RoktUXConfig.Builder().build()
        XCTAssertEqual(config.colorMode, .system)
        XCTAssertNil(config.imageLoader)
        XCTAssertEqual(config.logLevel, .none)
    }

    func testCustomColorMode() {
        let config = RoktUXConfig.Builder()
            .colorMode(.dark)
            .build()
        XCTAssertEqual(config.colorMode, .dark)
    }

    func testCustomImageLoader() {
        let mockImageLoader = MockImageLoader()
        let config = RoktUXConfig.Builder()
            .imageLoader(mockImageLoader)
            .build()
        XCTAssertNotNil(config.imageLoader)
        XCTAssertTrue(config.imageLoader === mockImageLoader)
    }

    func testLogLevel() {
        let config = RoktUXConfig.Builder()
            .logLevel(.debug)
            .build()
        XCTAssertEqual(config.logLevel, .debug)
    }

    func testLogLevelVerbose() {
        let config = RoktUXConfig.Builder()
            .logLevel(.verbose)
            .build()
        XCTAssertEqual(config.logLevel, .verbose)
    }

    func testDeprecatedEnableLogging() {
        let config = RoktUXConfig.Builder()
            .enableLogging(true)
            .build()
        XCTAssertEqual(config.logLevel, .debug)
    }

    func testDeprecatedEnableLoggingFalse() {
        let config = RoktUXConfig.Builder()
            .enableLogging(false)
            .build()
        XCTAssertEqual(config.logLevel, .none)
    }
}

class MockImageLoader: RoktUXImageLoader {
    func loadImage(urlString: String, completion: @escaping (Result<UIImage?, Error>) -> Void) {
        completion(.success(nil))
    }
}
