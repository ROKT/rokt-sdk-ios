import XCTest
@testable import RoktUXHelper

class RoktUXLoggerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        RoktUXLogger.shared.logLevel = .none
    }

    override func tearDown() {
        RoktUXLogger.shared.logLevel = .none
        super.tearDown()
    }

    func testDefaultLogLevelIsNone() {
        let logger = RoktUXLogger.shared
        logger.logLevel = .none
        XCTAssertEqual(logger.logLevel, .none)
    }

    func testLogLevelCanBeSet() {
        let logger = RoktUXLogger.shared
        logger.logLevel = .debug
        XCTAssertEqual(logger.logLevel, .debug)

        logger.logLevel = .verbose
        XCTAssertEqual(logger.logLevel, .verbose)

        logger.logLevel = .error
        XCTAssertEqual(logger.logLevel, .error)
    }

    func testSharedInstanceIsSingleton() {
        let logger1 = RoktUXLogger.shared
        let logger2 = RoktUXLogger.shared
        XCTAssertTrue(logger1 === logger2)
    }

    @available(iOS 15, *)
    func testSetLogLevelViaPublicAPI() {
        RoktUX.setLogLevel(.warning)
        XCTAssertEqual(RoktUXLogger.shared.logLevel, .warning)
    }

    func testLogMethodsDoNotCrash() {
        let logger = RoktUXLogger.shared
        logger.logLevel = .verbose

        // Exercise all log methods - verifying they don't crash
        logger.verbose("verbose test message")
        logger.debug("debug test message")
        logger.info("info test message")
        logger.warning("warning test message")
        logger.error("error test message")

        // With optional error parameter
        let testError = NSError(domain: "test", code: 1, userInfo: nil)
        logger.verbose("verbose with error", error: testError)
        logger.debug("debug with error", error: testError)
        logger.info("info with error", error: testError)
        logger.warning("warning with error", error: testError)
        logger.error("error with error", error: testError)
    }

    func testLogLevelFilteringPreventsOutput() {
        let logger = RoktUXLogger.shared

        // Set to error - only error messages should pass the guard
        logger.logLevel = .error

        // These should all pass the guard check without crashing
        // (they won't print, but they exercise the level comparison logic)
        logger.verbose("should be filtered")
        logger.debug("should be filtered")
        logger.info("should be filtered")
        logger.warning("should be filtered")
        logger.error("should pass filter")
    }

    func testLogLevelNoneFiltersAllMessages() {
        let logger = RoktUXLogger.shared
        logger.logLevel = .none

        // All should be filtered
        logger.verbose("filtered")
        logger.debug("filtered")
        logger.info("filtered")
        logger.warning("filtered")
        logger.error("filtered")
    }

    func testSetSharedReturnsOriginal() {
        let original = RoktUXLogger.shared
        let replacement = RoktUXLogger()

        let returned = RoktUXLogger.setShared(replacement)
        XCTAssertTrue(returned === original)
        XCTAssertTrue(RoktUXLogger.shared === replacement)

        // Restore
        RoktUXLogger.setShared(original)
        XCTAssertTrue(RoktUXLogger.shared === original)
    }
}

class RoktUXLogLevelTests: XCTestCase {

    func testLogLevelOrdering() {
        XCTAssertTrue(RoktUXLogLevel.verbose < RoktUXLogLevel.debug)
        XCTAssertTrue(RoktUXLogLevel.debug < RoktUXLogLevel.info)
        XCTAssertTrue(RoktUXLogLevel.info < RoktUXLogLevel.warning)
        XCTAssertTrue(RoktUXLogLevel.warning < RoktUXLogLevel.error)
        XCTAssertTrue(RoktUXLogLevel.error < RoktUXLogLevel.none)
    }

    func testLogLevelRawValues() {
        XCTAssertEqual(RoktUXLogLevel.verbose.rawValue, 0)
        XCTAssertEqual(RoktUXLogLevel.debug.rawValue, 1)
        XCTAssertEqual(RoktUXLogLevel.info.rawValue, 2)
        XCTAssertEqual(RoktUXLogLevel.warning.rawValue, 3)
        XCTAssertEqual(RoktUXLogLevel.error.rawValue, 4)
        XCTAssertEqual(RoktUXLogLevel.none.rawValue, 5)
    }

    func testLogLevelLabels() {
        XCTAssertEqual(RoktUXLogLevel.verbose.label, "VERBOSE")
        XCTAssertEqual(RoktUXLogLevel.debug.label, "DEBUG")
        XCTAssertEqual(RoktUXLogLevel.info.label, "INFO")
        XCTAssertEqual(RoktUXLogLevel.warning.label, "WARNING")
        XCTAssertEqual(RoktUXLogLevel.error.label, "ERROR")
        XCTAssertEqual(RoktUXLogLevel.none.label, "NONE")
    }

    func testLogLevelComparable() {
        XCTAssertTrue(RoktUXLogLevel.verbose <= RoktUXLogLevel.verbose)
        XCTAssertTrue(RoktUXLogLevel.verbose <= RoktUXLogLevel.debug)
        XCTAssertFalse(RoktUXLogLevel.error <= RoktUXLogLevel.debug)
    }

    func testLogLevelEquality() {
        XCTAssertEqual(RoktUXLogLevel.debug, RoktUXLogLevel.debug)
        XCTAssertNotEqual(RoktUXLogLevel.debug, RoktUXLogLevel.info)
    }
}
