import XCTest
@testable import Rokt_Widget

final class TestRoktLogger: XCTestCase {

    override func setUp() {
        super.setUp()
        RoktLogger.shared.logLevel = .none
    }

    override func tearDown() {
        RoktLogger.shared.logLevel = .none
        super.tearDown()
    }

    func test_defaultLogLevel_isNone() {
        // Arrange
        let logger = RoktLogger.shared
        logger.logLevel = .none

        // Assert
        XCTAssertEqual(logger.logLevel, .none)
    }

    func test_logLevel_canBeSet() {
        // Arrange
        let logger = RoktLogger.shared

        // Act & Assert
        logger.logLevel = .debug
        XCTAssertEqual(logger.logLevel, .debug)

        logger.logLevel = .verbose
        XCTAssertEqual(logger.logLevel, .verbose)

        logger.logLevel = .error
        XCTAssertEqual(logger.logLevel, .error)
    }

    func test_sharedInstance_isSingleton() {
        // Arrange
        let logger1 = RoktLogger.shared
        let logger2 = RoktLogger.shared

        // Assert
        XCTAssertTrue(logger1 === logger2)
    }

    func test_setLogLevel_viaPublicAPI() {
        // Arrange & Act
        Rokt.setLogLevel(.warning)

        // Assert
        XCTAssertEqual(RoktLogger.shared.logLevel, .warning)
    }

    func test_setShared_returnsOriginal() {
        // Arrange
        let original = RoktLogger.shared
        let replacement = RoktLogger()

        // Act
        let returned = RoktLogger.setShared(replacement)

        // Assert
        XCTAssertTrue(returned === original)
        XCTAssertTrue(RoktLogger.shared === replacement)

        // Cleanup
        RoktLogger.setShared(original)
    }
}

final class TestRoktLogLevel: XCTestCase {

    func test_logLevel_ordering() {
        XCTAssertTrue(RoktLogLevel.verbose < RoktLogLevel.debug)
        XCTAssertTrue(RoktLogLevel.debug < RoktLogLevel.info)
        XCTAssertTrue(RoktLogLevel.info < RoktLogLevel.warning)
        XCTAssertTrue(RoktLogLevel.warning < RoktLogLevel.error)
        XCTAssertTrue(RoktLogLevel.error < RoktLogLevel.none)
    }

    func test_logLevel_rawValues() {
        XCTAssertEqual(RoktLogLevel.verbose.rawValue, 0)
        XCTAssertEqual(RoktLogLevel.debug.rawValue, 1)
        XCTAssertEqual(RoktLogLevel.info.rawValue, 2)
        XCTAssertEqual(RoktLogLevel.warning.rawValue, 3)
        XCTAssertEqual(RoktLogLevel.error.rawValue, 4)
        XCTAssertEqual(RoktLogLevel.none.rawValue, 5)
    }

    func test_logLevel_labels() {
        XCTAssertEqual(RoktLogLevel.verbose.label, "VERBOSE")
        XCTAssertEqual(RoktLogLevel.debug.label, "DEBUG")
        XCTAssertEqual(RoktLogLevel.info.label, "INFO")
        XCTAssertEqual(RoktLogLevel.warning.label, "WARNING")
        XCTAssertEqual(RoktLogLevel.error.label, "ERROR")
        XCTAssertEqual(RoktLogLevel.none.label, "NONE")
    }

    func test_logLevel_comparable() {
        XCTAssertTrue(RoktLogLevel.verbose <= RoktLogLevel.verbose)
        XCTAssertTrue(RoktLogLevel.verbose <= RoktLogLevel.debug)
        XCTAssertFalse(RoktLogLevel.error <= RoktLogLevel.debug)
    }

    func test_logLevel_equality() {
        XCTAssertEqual(RoktLogLevel.debug, RoktLogLevel.debug)
        XCTAssertNotEqual(RoktLogLevel.debug, RoktLogLevel.info)
    }

    @available(iOS 15.0, *)
    func test_toUXLogLevel_mapping() {
        XCTAssertEqual(RoktLogLevel.verbose.toUXLogLevel().rawValue, 0)
        XCTAssertEqual(RoktLogLevel.debug.toUXLogLevel().rawValue, 1)
        XCTAssertEqual(RoktLogLevel.info.toUXLogLevel().rawValue, 2)
        XCTAssertEqual(RoktLogLevel.warning.toUXLogLevel().rawValue, 3)
        XCTAssertEqual(RoktLogLevel.error.toUXLogLevel().rawValue, 4)
        XCTAssertEqual(RoktLogLevel.none.toUXLogLevel().rawValue, 5)
    }
}
