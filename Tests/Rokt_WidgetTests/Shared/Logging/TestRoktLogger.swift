import XCTest
@testable import Rokt_Widget
@testable internal import RoktUXHelper

final class TestRoktLogger: XCTestCase {

    private var originalLogger: RoktLogger!
    private var originalUXLogLevel: RoktUXLogLevel!

    override func setUp() {
        super.setUp()
        originalLogger = RoktLogger.setShared(RoktLogger())
        originalUXLogLevel = RoktUXLogger.shared.logLevel
    }

    override func tearDown() {
        RoktLogger.setShared(originalLogger)
        RoktUX.setLogLevel(originalUXLogLevel)
        super.tearDown()
    }

    func test_defaultLogLevel_isNone() {
        // Arrange
        let logger = RoktLogger()

        // Assert
        XCTAssertEqual(logger.logLevel, .none)
    }

    func test_sessionId_canBeSetAndCleared() {
        let logger = RoktLogger()
        XCTAssertNil(logger.sessionId)

        logger.sessionId = "session-abc"
        XCTAssertEqual(logger.sessionId, "session-abc")

        logger.sessionId = nil
        XCTAssertNil(logger.sessionId)
    }

    func test_logMethods_doNotCrashWithSessionId() {
        let logger = RoktLogger.shared
        logger.logLevel = .verbose
        logger.sessionId = "session-for-log"

        logger.verbose("verbose test message")
        logger.debug("debug test message")
        logger.info("info test message")
        logger.warning("warning test message")
        logger.error("error test message")

        let testError = NSError(domain: "test", code: 1, userInfo: nil)
        logger.verbose("verbose with error", error: testError)
        logger.debug("debug with error", error: testError)
        logger.info("info with error", error: testError)
        logger.warning("warning with error", error: testError)
        logger.error("error with error", error: testError)
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
        XCTAssertEqual(RoktUXLogger.shared.logLevel, .warning)
    }

    func test_allLogLevels_filterAndEmitExactlyOnce() {
        let levels: [RoktLogLevel] = [.verbose, .debug, .info, .warning, .error, .none]
        for threshold in levels {
            let recorder = RoktLogRecorder()
            let logger = RoktLogger(output: recorder.record)
            logger.logLevel = threshold

            logger.verbose("message", file: "Probe.swift", function: "probe()", line: 7)
            logger.debug("message", file: "Probe.swift", function: "probe()", line: 7)
            logger.info("message", file: "Probe.swift", function: "probe()", line: 7)
            logger.warning("message", file: "Probe.swift", function: "probe()", line: 7)
            logger.error("message", file: "Probe.swift", function: "probe()", line: 7)

            let expected = levels.filter { $0 != .none && $0 >= threshold }.map {
                "[Rokt/\($0.label)] [Probe.swift probe():7] message"
            }
            XCTAssertEqual(recorder.messages, expected, "Threshold: \(threshold)")
        }
    }

    func test_formatting_preservesMessageErrorAndSession() {
        let recorder = RoktLogRecorder()
        let logger = RoktLogger(output: recorder.record)
        logger.logLevel = .debug
        logger.sessionId = "synthetic-session"
        let error = NSError(domain: "LoggingTest", code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "synthetic failure 100% %@"])
        let message = "Progress 100% %@ — café 🚀\nsecond line"

        logger.debug(message, error: error, file: "/synthetic/Probe.swift", function: "probe()", line: 7)
        logger.sessionId = nil
        logger.info("ready", file: "Probe.swift", function: "probe()", line: 8)

        XCTAssertEqual(recorder.messages, [
            "[Rokt/DEBUG] [Probe.swift probe():7] \(message) | Error: synthetic failure 100% %@ | sessionId=synthetic-session",
            "[Rokt/INFO] [Probe.swift probe():8] ready"
        ])
    }

    func test_output_canReenterLoggerWithoutDeadlocking() {
        let finished = expectation(description: "reentrant output completes")
        let logger = RoktLogger(output: { _ in
            RoktLogger.shared.logLevel = .none
            RoktLogger.shared.sessionId = nil
            finished.fulfill()
        })
        RoktLogger.setShared(logger)
        logger.logLevel = .debug

        DispatchQueue.global().async { logger.debug("reentrant output") }

        wait(for: [finished], timeout: 5)
        XCTAssertEqual(logger.logLevel, .none)
        XCTAssertNil(logger.sessionId)
    }

    func test_concurrentLoggingAndConfiguration_emitsEachAcceptedMessageOnce() {
        let recorder = RoktLogRecorder()
        let logger = RoktLogger(output: recorder.record)
        let finished = expectation(description: "concurrent logging completes")

        DispatchQueue.global().async {
            DispatchQueue.concurrentPerform(iterations: 100) { index in
                logger.logLevel = index.isMultiple(of: 2) ? .verbose : .error
                logger.sessionId = index.isMultiple(of: 2) ? "synthetic-session" : nil
                logger.error("message-\(index)", file: "Probe.swift", function: "probe()", line: 7)
            }
            finished.fulfill()
        }

        wait(for: [finished], timeout: 5)
        let messages = recorder.messages.map { $0.components(separatedBy: " | sessionId=").first ?? "" }
        XCTAssertEqual(messages.count, 100)
        XCTAssertEqual(Set(messages), Set((0..<100).map { "[Rokt/ERROR] [Probe.swift probe():7] message-\($0)" }))
    }

    func test_defaultOutput_acceptsLiteralFormatTokensAndUnicode() {
        let logger = RoktLogger()
        logger.logLevel = .debug
        logger.debug("NSLog sink probe: 100% %@ — café 🚀\nsecond line")
    }

    func test_failedPlatformEvent_logsFailureWithoutPayloadValues() {
        let recorder = RoktLogRecorder()
        let logger = RoktLogger(output: recorder.record)
        logger.logLevel = .debug
        RoktLogger.setShared(logger)

        PlatformEventProcessor().process(
            ["events": "synthetic-payload-value", "attributes": ["example": "synthetic-attribute-value"]],
            executeId: "synthetic-execution",
            cacheProperties: nil
        )

        XCTAssertEqual(recorder.messages.count, 1)
        XCTAssertTrue(recorder.messages.first?.contains("[Rokt/ERROR]") == true)
        XCTAssertTrue(recorder.messages.first?.contains("Failed to process platform events") == true)
        XCTAssertFalse(recorder.messages.joined().contains("synthetic-payload-value"))
        XCTAssertFalse(recorder.messages.joined().contains("synthetic-attribute-value"))
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

private final class RoktLogRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedMessages: [String] = []

    var messages: [String] { lock.withLock { recordedMessages } }

    func record(_ message: String) {
        lock.withLock { recordedMessages.append(message) }
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
