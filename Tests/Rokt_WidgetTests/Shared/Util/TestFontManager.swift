import XCTest
import CoreText
@testable import Rokt_Widget

/// Mocker invokes request hooks off the test thread, so attempt counts are guarded.
private final class Counter {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }
}

/// Diagnostics are delivered off the test thread, so captured call stacks are guarded.
private final class Traces {
    private let lock = NSLock()
    private var values: [String] = []

    func append(_ value: String) {
        lock.lock()
        values.append(value)
        lock.unlock()
    }

    func contains(_ predicate: (String) -> Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return values.contains(where: predicate)
    }

    func count(where predicate: (String) -> Bool) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return values.filter(predicate).count
    }
}

class TestFontManager: XCTestCase {
    var hasFetched = false
    var errors = [String]()

    override func setUp() {
        super.setUp()

        if !hasFetched {
            FontManager.getExistingFontsByPostScriptName()
            hasFetched = true
        }
        Rokt.shared.roktImplementation.roktTagId = "123"
        Rokt.shared.roktImplementation.isInitFailedForFont = false

        self.stubDiagnostics(onDiagnosticsReceive: { (error) in
            self.errors.append(error)
        })

        XCTestCase.prepareTestFiles()
        XCTestCase.deleteAllTestFiles()

    }

    override func tearDown() {
        XCTestCase.deleteAllTestFiles()
        Rokt.shared.roktImplementation.initFeatureFlags = InitFeatureFlags(
            roktTrackingStatus: true,
            shouldLogFontHappyPath: false,
            shouldUseFontRegisterWithUrl: false,
            featureFlags: [:]
        )
        FontManager.resetFontRecoveryState()
        FontManager.resetDiskPressureState()
        FontManager.maxFontRecoveryAttempts = 2
        FontManager.fontRecoveryBackoff = .seconds(1)
        FontManager.fileUrlResolverOverride = nil
        Rokt.shared.roktImplementation.isInitFailedForFont = false

        super.tearDown()
    }

    func test_isDownloadFontRequired_withNewFont_shouldReturnTrue() {
        let isDownloadFontRequired = FontManager.isDownloadingFontRequired(font: FontModel(name: "test", url: "test url"))

        XCTAssertTrue(isDownloadFontRequired)
    }

    func test_saveFonDetails_withPostScript_usesPostScriptNameInsteadOfFamilyName() throws {
        let font = FontModel(name: "test font", url: "test url", postScriptName: "font post script")

        FontManager.saveFontDetails(font: font)

        let fontArray = try XCTUnwrap(FontRepository.loadAllFontURLs())
        let fontDetail = try XCTUnwrap(FontRepository.loadFontDetail(key: "test url"))

        XCTAssertEqual(fontArray, ["test url"])
        XCTAssertEqual(fontDetail["name"], "font post script")
    }

    func test_saveFontDetails_withoutPostScript_usesFamilyName() throws {
        let font = FontModel(name: "test font", url: "test url", postScriptName: nil)

        FontManager.saveFontDetails(font: font)

        let fontArray = try XCTUnwrap(FontRepository.loadAllFontURLs())
        let fontDetail = try XCTUnwrap(FontRepository.loadFontDetail(key: "test url"))

        XCTAssertEqual(fontArray, ["test url"])
        XCTAssertEqual(fontDetail["name"], "test font")
    }

    func test_isFontExpired_forUnexpiredDates_returnsFalse() {
        let now = Date().timeIntervalSince1970
        let about6Days = Calendar.current.date(byAdding: .day, value: -6, to: Date())!.timeIntervalSince1970
        let about2Days = Calendar.current.date(byAdding: .day, value: -2, to: Date())!.timeIntervalSince1970

        XCTAssertFalse(FontManager.isFontExpired(timeStamp: now))
        XCTAssertFalse(FontManager.isFontExpired(timeStamp: about2Days))
        XCTAssertFalse(FontManager.isFontExpired(timeStamp: about6Days))
    }

    func test_isFontExpired_forUnexpiredDate_returnsTrue() {
        let about9Days = Calendar.current.date(byAdding: .day, value: -9, to: Date())!.timeIntervalSince1970
        XCTAssertTrue(FontManager.isFontExpired(timeStamp: about9Days))
    }

    func test_getFileURL_returnsMappedURL() throws {
        let fontDirectoryUrl = try XCTUnwrap(FontRepository.getFontDirectoryUrl())
        let expectedURL = fontDirectoryUrl.appendingPathComponent("test.ttf")

        let url = try XCTUnwrap(FontManager.getFileUrl(name: "test"))

        XCTAssertEqual(url, expectedURL)
    }

    func test_downloadFonts_whenFreeSpaceIsLow_skipsDownloadAndSettles() {
        FontManager.freeDiskBytesOverride = 0
        FontManager.minimumFreeDiskBytesForFontDownload = 1_000_000

        let requestCount = Counter()
        let settled = expectation(description: "batch settled without download")
        let fontURL = "https://font.test/low-space.ttf"
        stubFontFileUrl(fontURL) {
            requestCount.increment()
        }

        FontManager.downloadFonts([
            FontModel(name: "low-space-font", url: fontURL)
        ]) {
            settled.fulfill()
        }

        wait(for: [settled], timeout: 15)
        XCTAssertEqual(requestCount.value, 0)
        XCTAssertTrue(FontManager.isFontDownloadBlockedByDiskPressure())
    }

    func test_handleFontDownloadResponse_withENOSPC_tripsCircuitAndReportsOnce() throws {
        let traces = captureDiagnosticStackTraces()
        let enospc = NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC))
        let downloadError = RoktHTTPClient.RoktDownloadError.downloadFailed(error: enospc)

        let firstSettled = expectation(description: "first enospc settled")
        RoktNetWorkAPI.handleFontDownloadResponse(
            font: FontModel(name: "enospc-font-1", url: "https://font.test/enospc-1.ttf"),
            destinationURL: try XCTUnwrap(FontManager.getFileUrl(name: "enospc-font-1")),
            downloadResponse: RoktDownloadResult(
                httpURLResponse: nil,
                downloadedFileLocalURL: nil,
                downloadError: downloadError
            ),
            onDownloadComplete: { firstSettled.fulfill() }
        )
        wait(for: [firstSettled], timeout: 15)

        let secondSettled = expectation(description: "second enospc settled")
        RoktNetWorkAPI.handleFontDownloadResponse(
            font: FontModel(name: "enospc-font-2", url: "https://font.test/enospc-2.ttf"),
            destinationURL: try XCTUnwrap(FontManager.getFileUrl(name: "enospc-font-2")),
            downloadResponse: RoktDownloadResult(
                httpURLResponse: nil,
                downloadedFileLocalURL: nil,
                downloadError: downloadError
            ),
            onDownloadComplete: { secondSettled.fulfill() }
        )
        wait(for: [secondSettled], timeout: 15)

        XCTAssertTrue(FontManager.isFontDownloadBlockedByDiskPressure())
        XCTAssertTrue(waitUntil {
            traces.count { $0.contains("No space left on device") } == 1
        }, "disk-full should be reported once per process")

        let requestCount = Counter()
        let skipped = expectation(description: "download skipped after circuit open")
        let blockedURL = "https://font.test/enospc-3.ttf"
        stubFontFileUrl(blockedURL) {
            requestCount.increment()
        }
        RoktNetWorkAPI.downloadFont(
            font: FontModel(name: "enospc-font-3", url: blockedURL),
            destinationURL: try XCTUnwrap(FontManager.getFileUrl(name: "enospc-font-3"))
        ) {
            skipped.fulfill()
        }
        wait(for: [skipped], timeout: 15)
        XCTAssertEqual(requestCount.value, 0, "circuit breaker must stop further downloads")
    }

    func test_isSystemFont_forSystemFont_returnsTrue() {
        let font = FontModel(name: "ArialMT", url: "")

        XCTAssertTrue(FontManager.isSystemFont(font: font))
    }

    func test_registerGraphicFont_registerDuplicate_sendsNoDiagnostics() {
        let font = UIFont.systemFont(ofSize: 15.0)
        let fontName = font.fontName as NSString
        let cgFont = CGFont(fontName)!

        FontManager.registerGraphicFont(cgFont: cgFont, fontUrlString: "Test", logLoadType: FontManager.logFontPreloadedType)

        let exp = expectation(description: "Test after 0.1 seconds")
        let result = XCTWaiter.wait(for: [exp], timeout: 0.1)

        if result == XCTWaiter.Result.timedOut {
            XCTAssertTrue(errors.isEmpty)
        } else {
            XCTFail("Diagnostics sent on reregister")
        }
    }
    @available(iOS 16.0, *)
    func test_registerURLFont_withError_registersFontError() {
        let font = UIFont.systemFont(ofSize: 15.0)
        let fontName = font.fontName as NSString
        let cgFont = CGFont(fontName)!

        FontManager.registerURLFont(fileUrl: URL.currentDirectory(), cgFont: cgFont,
                                    fontUrlString: "Test",
                                    logLoadType: FontManager.logFontPreloadedType)

        let exp = expectation(description: "Test after 0.1 seconds")
        let result = XCTWaiter.wait(for: [exp], timeout: 0.1)

        if result == XCTWaiter.Result.timedOut {
            XCTAssertTrue(errors.contains("[FONT]"))
        } else {
            XCTFail("No diagnostics")
        }

    }

    func test_isSystemFont_forNonExistentFont_shouldReturnFalse() {
        let font = FontModel(name: "some other font", url: "")

        XCTAssertFalse(FontManager.isSystemFont(font: font))
    }

    func test_isFontFileExist_returnsFalseWhenFileMissing() {
        XCTAssertFalse(FontManager.isFontFileExist(name: "missing-font-file"))
    }

    func test_isFontFileExist_returnsTrueWhenFileExists() throws {
        try XCTestCase.writeFontFileToCache(named: "cached-font-file")

        XCTAssertTrue(FontManager.isFontFileExist(name: "cached-font-file"))
    }

    func test_isDownloadingFontRequired_withValidCachedFont_returnsFalse() throws {
        let font = FontModel(name: "cached-font", url: "https://font.test/cached.ttf")
        let saveExpectation = expectation(description: "save font details")

        FontRepository.saveFontDetail(
            key: font.url,
            values: [
                FontManager.keyName: "cached-font",
                FontManager.keyTimestamp: "\(Date().timeIntervalSince1970)"
            ]
        ) {
            saveExpectation.fulfill()
        }

        waitForExpectations(timeout: 15)
        try XCTestCase.writeFontFileToCache(named: "cached-font")

        XCTAssertFalse(FontManager.isDownloadingFontRequired(font: font))
    }

    func test_isDownloadingFontRequired_withExpiredCacheAndTemporaryFlag_returnsTrue() throws {
        Rokt.shared.roktImplementation.initFeatureFlags = InitFeatureFlags(
            featureFlags: ["mobile-sdk-use-temporary-font-cache": FeatureFlagItem(match: true)]
        )

        let font = FontModel(name: "expired-font", url: "https://font.test/expired.ttf")
        let expiredTimestamp = Calendar.current.date(byAdding: .day, value: -10, to: Date())!.timeIntervalSince1970
        let saveExpectation = expectation(description: "save font details")

        FontRepository.saveFontDetail(
            key: font.url,
            values: [
                FontManager.keyName: "expired-font",
                FontManager.keyTimestamp: "\(expiredTimestamp)"
            ]
        ) {
            saveExpectation.fulfill()
        }

        waitForExpectations(timeout: 15)
        try XCTestCase.writeFontFileToCache(named: "expired-font")

        XCTAssertTrue(FontManager.isDownloadingFontRequired(font: font))
    }

    func test_removeUnusedFonts_removesFontsNotInProvidedList() throws {
        let keepFont = FontModel(name: "keep-font", url: "https://font.test/keep.ttf")
        let removeFont = FontModel(name: "remove-font", url: "https://font.test/remove.ttf")

        let saveKeepExpectation = expectation(description: "save keep url")
        let saveRemoveExpectation = expectation(description: "save remove url")
        let saveRemoveDetailExpectation = expectation(description: "save remove detail")

        FontRepository.saveFontUrl(key: keepFont.url) {
            saveKeepExpectation.fulfill()
        }
        FontRepository.saveFontUrl(key: removeFont.url) {
            saveRemoveExpectation.fulfill()
        }
        FontRepository.saveFontDetail(
            key: removeFont.url,
            values: [
                FontManager.keyName: "remove-font",
                FontManager.keyTimestamp: "\(Date().timeIntervalSince1970)"
            ]
        ) {
            saveRemoveDetailExpectation.fulfill()
        }

        waitForExpectations(timeout: 15)
        try XCTestCase.writeFontFileToCache(named: "remove-font")

        FontManager.removeUnusedFonts(fonts: [keepFont])

        let waitExpectation = expectation(description: "wait for async cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            waitExpectation.fulfill()
        }
        waitForExpectations(timeout: 2)

        let remainingURLs = try XCTUnwrap(FontRepository.loadAllFontURLs())

        XCTAssertEqual(remainingURLs, [keepFont.url])
        XCTAssertNil(FontRepository.loadFontDetail(key: removeFont.url))
        XCTAssertFalse(FontManager.isFontFileExist(name: "remove-font"))
    }

    func test_reRegisterFonts_withNoPendingFonts_callsCompletion() {
        let expectation = expectation(description: "reRegisterFonts completion")

        FontManager.reRegisterFonts {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func test_downloadFonts_should_call_onFontDownloadComplete_when_fonts_are_empty() {
        // Arrange
        let fonts: [FontModel] = []
        let expectation = XCTestExpectation(description: "Download complete")

        // Act
        FontManager.downloadFonts(fonts) {
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 5)
    }

    func test_downloadFonts_should_call_onFontDownloadComplete_when_fonts_are_failed_to_download() {
        // Arrange
        let fonts: [FontModel] = [FontModel(name: "some other font", url: "")]
        let expectation = XCTestExpectation(description: "Download complete")

        // Act
        FontManager.downloadFonts(fonts) {
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 5)
    }

    func test_downloadFonts_should_call_onFontDownloadComplete_when_fonts_download_success() {
        // Arrange
        let fontUrl = "https://somefont.ttf"
        let fonts: [FontModel] = [FontModel(name: "some font", url: fontUrl)]
        let expectation = XCTestExpectation(description: "Download complete")
        self.stubFontFileUrl(fontUrl)

        // Act
        FontManager.downloadFonts(fonts) {
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 5)
    }

    func test_downloadFonts_should_call_onFontDownloadComplete_only_once_when_font_downloads_are_success() {
        // Arrange
        let fontUrl = "https://somefont.ttf"
        let fonts: [FontModel] = [FontModel(name: "some font", url: fontUrl), FontModel(name: "some other font", url: fontUrl)]
        let expectation = XCTestExpectation(description: "Download complete")
        self.stubFontFileUrl(fontUrl)
        var callbackCount = 0

        // Act
        FontManager.downloadFonts(fonts) {
            expectation.fulfill()
            callbackCount += 1
        }

        // Assert
        wait(for: [expectation], timeout: 5)
        XCTAssertEqual(1, callbackCount)
    }

    // MARK: - Completion is driven by settled count, not font order

    func test_downloadFonts_callsCompletion_whenLastFontIsAlreadyCached() throws {
        // Cache recovery is covered separately below. A stubbed font file cannot register,
        // and letting it re-fetch here would only race with the assertion.
        FontManager.maxFontRecoveryAttempts = 0

        let downloadUrl = "https://font.test/needs-download.ttf"
        let cachedName = "already-cached-font"
        let cachedUrl = "https://font.test/already-cached.ttf"
        addTeardownBlock { self.removeCachedFontFile(named: cachedName) }

        stubFontFileUrl(downloadUrl)
        try seedCachedFont(name: cachedName, url: cachedUrl)

        let completion = expectation(description: "onFontDownloadComplete")

        FontManager.downloadFonts([
            FontModel(name: "needs-download-font", url: downloadUrl),
            FontModel(name: cachedName, url: cachedUrl)
        ]) {
            completion.fulfill()
        }

        wait(for: [completion], timeout: 10)
    }

    func test_downloadFonts_callsCompletion_whenLastFontIsSystemFont() {
        let downloadUrl = "https://font.test/needs-download.ttf"
        stubFontFileUrl(downloadUrl)

        let completion = expectation(description: "onFontDownloadComplete")

        FontManager.downloadFonts([
            FontModel(name: "needs-download-font", url: downloadUrl),
            FontModel(name: "ArialMT", url: "")
        ]) {
            completion.fulfill()
        }

        wait(for: [completion], timeout: 10)
    }

    func test_downloadFonts_whenAFontPathCannotBeResolved_stillSettlesTheBatch() {
        // An unresolvable path used to return early and abandon the whole batch, leaving
        // init waiting forever on the fonts that came after it.
        FontManager.fileUrlResolverOverride = { _ in nil }

        let completion = expectation(description: "onFontDownloadComplete")

        FontManager.downloadFonts([
            FontModel(name: "unresolvable-font-a", url: "https://font.test/unresolvable-a.ttf"),
            FontModel(name: "unresolvable-font-b", url: "https://font.test/unresolvable-b.ttf")
        ]) {
            completion.fulfill()
        }

        wait(for: [completion], timeout: 10)
        XCTAssertTrue(Rokt.shared.roktImplementation.isInitFailedForFont,
                      "the failure should still be recorded for diagnostics")
    }

    func test_downloadFont_whenEveryAttemptFailsRetriably_settlesOnceAfterRetriesAreExhausted() throws {
        // A retrying font must still settle, otherwise the batch it belongs to never
        // completes and init waits on a font that will never arrive.
        let url = "https://font.test/always-500.ttf"
        let attempts = Counter()

        stubFontFileUrl(url, statusCode: 500) { attempts.increment() }

        let font = FontModel(name: "always-500-font", url: url)
        let fileUrl = try XCTUnwrap(FontManager.getFileUrl(name: font.name))
        let settled = expectation(description: "download settled")
        var settleCount = 0

        RoktNetWorkAPI.downloadFont(font: font, destinationURL: fileUrl) {
            settleCount += 1
            settled.fulfill()
        }

        wait(for: [settled], timeout: 15)

        XCTAssertEqual(settleCount, 1, "the completion must fire exactly once, not once per attempt")
        XCTAssertEqual(attempts.value, maxRetries + 1,
                       "the initial attempt plus every retry should be issued before settling")
    }

    func test_handleFontDownloadResponse_whenResponseHasNeitherErrorNorFile_isReportedSeparately() throws {
        // This response shape used to fall through every branch and never settle. It now
        // settles, but it must not be logged as a download failure carrying a nil error.
        let traces = captureDiagnosticStackTraces()

        let font = FontModel(name: "incomplete-response-font", url: "https://font.test/incomplete.ttf")
        let settled = expectation(description: "settled")

        RoktNetWorkAPI.handleFontDownloadResponse(
            font: font,
            destinationURL: try XCTUnwrap(FontManager.getFileUrl(name: font.name)),
            downloadResponse: RoktDownloadResult(
                httpURLResponse: nil,
                downloadedFileLocalURL: nil,
                downloadError: nil
            ),
            onDownloadComplete: { settled.fulfill() }
        )

        wait(for: [settled], timeout: 15)

        XCTAssertTrue(waitUntil { traces.contains { $0.contains("missing both error and file") } },
                      "a malformed response should be reported on its own line")
        XCTAssertFalse(traces.contains { $0.contains("Error downloading font") },
                       "it should not masquerade as a download failure with a nil error")
    }

    func test_handleFontDownloadResponse_withTerminalDownloadError_keepsTheExistingDiagnosticShape() throws {
        // The `[FONT]` rows for real download failures are already monitored, so splitting
        // the malformed case out must not change how a genuine failure reads.
        let traces = captureDiagnosticStackTraces()

        let font = FontModel(name: "terminal-error-font", url: "https://font.test/terminal.ttf")
        let settled = expectation(description: "settled")

        RoktNetWorkAPI.handleFontDownloadResponse(
            font: font,
            destinationURL: try XCTUnwrap(FontManager.getFileUrl(name: font.name)),
            downloadResponse: RoktDownloadResult(
                httpURLResponse: nil,
                downloadedFileLocalURL: nil,
                downloadError: NSError(domain: "Custom", code: 1)
            ),
            onDownloadComplete: { settled.fulfill() },
            retryCount: maxRetries
        )

        wait(for: [settled], timeout: 15)

        XCTAssertTrue(waitUntil { traces.contains { $0.contains("Error downloading font") } },
                      "a genuine download failure should keep its existing diagnostic shape")
        XCTAssertFalse(traces.contains { $0.contains("missing both error and file") },
                       "a real error should not be reported as a malformed response")
    }

    // MARK: - Cache recovery

    func test_invalidateCachedFont_alsoRemovesTheDownloadedUrlEntry() throws {
        // `removeFont` reads the detail before removing the URL entry, so an invalidation
        // that drops only the detail strands the entry where nothing can clean it up.
        let name = "invalidated-font"
        let url = "https://font.test/invalidated.ttf"
        addTeardownBlock { self.removeCachedFontFile(named: name) }

        let urlSaved = expectation(description: "font url saved")
        FontRepository.saveFontUrl(key: url) { urlSaved.fulfill() }
        wait(for: [urlSaved], timeout: 15)
        try seedCachedFont(name: name, url: url)

        let invalidated = expectation(description: "font invalidated")
        FontManager.invalidateCachedFont(FontModel(name: name, url: url)) { invalidated.fulfill() }
        wait(for: [invalidated], timeout: 15)

        XCTAssertFalse(FontManager.isFontFileExist(name: name))
        XCTAssertNil(FontRepository.loadFontDetail(key: url))
        XCTAssertFalse(FontRepository.loadAllFontURLs()?.contains(url) ?? false,
                       "the URL entry has to go too, otherwise removeUnusedFonts can never reclaim it")
    }

    /// Replaces the default diagnostics stub so a test can read the call stacks rather
    /// than just the error codes.
    private func captureDiagnosticStackTraces() -> Traces {
        let traces = Traces()
        stubDiagnostics(onDiagnosticsModelReceive: { traces.append($0.stackTrace) })
        return traces
    }

    func test_registerFont_withUnregisterableCachedFont_invalidatesCacheForReDownload() throws {
        // Keep the re-fetch pending so the assertion sees only the invalidation.
        FontManager.fontRecoveryBackoff = .seconds(60)

        let name = "corrupt-cached-font"
        let url = "https://font.test/corrupt.ttf"
        addTeardownBlock { self.removeCachedFontFile(named: name) }

        let font = FontModel(name: name, url: url)
        try seedCachedFont(name: name, url: url)
        let fileUrl = try XCTUnwrap(FontManager.getFileUrl(name: name))

        FontManager.registerFont(font: font, fileUrl: fileUrl)

        XCTAssertTrue(
            waitUntil { FontManager.isDownloadingFontRequired(font: font) },
            "an unregisterable cached font should be queued for download instead of " +
            "resolving to the fallback font on every render"
        )
    }

    func test_registerFont_withUnregisterableCachedFont_stopsRecoveringAtAttemptLimit() throws {
        FontManager.fontRecoveryBackoff = .seconds(60)
        FontManager.maxFontRecoveryAttempts = 1

        let name = "repeatedly-bad-font"
        let url = "https://font.test/repeatedly-bad.ttf"
        addTeardownBlock { self.removeCachedFontFile(named: name) }

        let font = FontModel(name: name, url: url)

        try seedCachedFont(name: name, url: url)
        let fileUrl = try XCTUnwrap(FontManager.getFileUrl(name: name))
        FontManager.registerFont(font: font, fileUrl: fileUrl)

        XCTAssertTrue(
            waitUntil { !FontManager.isFontFileExist(name: name) },
            "the first failure should invalidate the cached file"
        )

        try seedCachedFont(name: name, url: url)
        FontManager.registerFont(font: font, fileUrl: fileUrl)

        XCTAssertTrue(
            FontManager.isFontFileExist(name: name),
            "once the attempt budget is spent the cache should be left alone rather than " +
            "looping on a font that will not register"
        )
    }

    func test_registerFont_afterSuccessfulRegistration_restoresTheRecoveryBudget() throws {
        // A font that recovers once must be recoverable again later in the same process,
        // so a successful registration has to release the attempt it consumed.
        FontManager.fontRecoveryBackoff = .seconds(60)
        FontManager.maxFontRecoveryAttempts = 1

        let name = "recovers-then-fails-font"
        let url = "https://font.test/recovers-then-fails.ttf"
        addTeardownBlock { self.removeCachedFontFile(named: name) }

        let font = FontModel(name: name, url: url)
        let fileUrl = try XCTUnwrap(FontManager.getFileUrl(name: name))

        try seedCachedFont(name: name, url: url)
        FontManager.registerFont(font: font, fileUrl: fileUrl)
        XCTAssertTrue(waitUntil { !FontManager.isFontFileExist(name: name) },
                      "the first failure should spend the only recovery attempt")

        try seedCachedFont(name: name, url: url, data: try Self.registerableFontData())
        FontManager.registerFont(font: font, fileUrl: fileUrl)

        try seedCachedFont(name: name, url: url)
        FontManager.registerFont(font: font, fileUrl: fileUrl)

        XCTAssertTrue(waitUntil { !FontManager.isFontFileExist(name: name) },
                      "the successful registration should have restored the budget, letting " +
                      "this later failure recover instead of being treated as exhausted")
    }

    func test_registerFont_withUnregisterableCachedFont_reDownloadsFontAfterBackoff() throws {
        // The invalidation is only half the recovery; the re-fetch has to actually run,
        // off the render path, for the font to come back.
        FontManager.fontRecoveryBackoff = .milliseconds(10)

        let name = "refetched-font"
        let url = "https://font.test/refetched.ttf"
        addTeardownBlock { self.removeCachedFontFile(named: name) }

        let requested = expectation(description: "font re-requested")
        requested.assertForOverFulfill = false
        stubFontFileUrl(url, data: try Self.registerableFontData()) { requested.fulfill() }

        let font = FontModel(name: name, url: url)
        try seedCachedFont(name: name, url: url)
        let fileUrl = try XCTUnwrap(FontManager.getFileUrl(name: name))

        FontManager.registerFont(font: font, fileUrl: fileUrl)

        wait(for: [requested], timeout: 15)
        XCTAssertTrue(waitUntil { FontManager.isFontFileExist(name: name) },
                      "the re-fetched font should be back in the cache and usable")
    }

    /// Registration only runs against genuine font bytes, and sourcing them from a font
    /// already on the device avoids committing a binary fixture. Large collections such as
    /// the emoji font are skipped to keep the read cheap.
    private static func registerableFontData() throws -> Data {
        for family in UIFont.familyNames {
            for fontName in UIFont.fontNames(forFamilyName: family) {
                let descriptor = CTFontCopyFontDescriptor(CTFontCreateWithName(fontName as CFString, 12, nil))

                guard let fontUrl = CTFontDescriptorCopyAttribute(descriptor, kCTFontURLAttribute) as? URL,
                      let data = try? Data(contentsOf: fontUrl),
                      data.count < 200_000,
                      let provider = CGDataProvider(data: data as CFData),
                      CGFont(provider) != nil
                else { continue }

                return data
            }
        }

        throw XCTSkip("no registerable font file is available on this device")
    }

    private func seedCachedFont(name: String, url: String, data: Data = Data([0x00])) throws {
        let saved = expectation(description: "font detail saved for \(name)")

        FontRepository.saveFontDetail(
            key: url,
            values: [
                FontManager.keyName: name,
                FontManager.keyTimestamp: "\(Date().timeIntervalSince1970)"
            ]
        ) {
            saved.fulfill()
        }

        wait(for: [saved], timeout: 15)

        try XCTestCase.writeFontFileToCache(named: name, data: data)
        XCTAssertFalse(FontManager.isDownloadingFontRequired(font: FontModel(name: name, url: url)))
    }

    private func removeCachedFontFile(named name: String) {
        guard let fileUrl = FontManager.getFileUrl(name: name) else { return }
        try? FileManager.default.removeItem(at: fileUrl)
    }

    /// The cache metadata is written asynchronously, so conditions that depend on it are
    /// polled rather than read once.
    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        return condition()
    }

    // MARK: - Thread Safety Tests

    func test_concurrentGetExistingFonts_doesNotCrash() {
        let expectation = self.expectation(description: "Concurrent font enumeration")
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "com.rokt.test.concurrent.enumerate", attributes: .concurrent)
        let iterations = 100

        for _ in 0..<iterations {
            group.enter()
            queue.async {
                FontManager.getExistingFontsByPostScriptName()
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)
    }

    func test_concurrentIsSystemFont_whileEnumerating_doesNotCrash() {
        let expectation = self.expectation(description: "Concurrent read/write")
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "com.rokt.test.concurrent.readwrite", attributes: .concurrent)
        let iterations = 100

        for i in 0..<iterations {
            group.enter()
            queue.async {
                if i % 2 == 0 {
                    FontManager.getExistingFontsByPostScriptName()
                } else {
                    _ = FontManager.isSystemFont(font: FontModel(name: "ArialMT", url: ""))
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)
    }

    func test_concurrentReRegisterFonts_whileEnumerating_doesNotCrash() {
        let expectation = self.expectation(description: "Concurrent reregister + enumerate")
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "com.rokt.test.concurrent.reregister", attributes: .concurrent)
        let iterations = 100

        for i in 0..<iterations {
            group.enter()
            queue.async {
                if i % 2 == 0 {
                    FontManager.getExistingFontsByPostScriptName()
                } else {
                    FontManager.reRegisterFonts()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)
    }

    func test_isSystemFont_returnsConsistentResults_underConcurrency() {
        FontManager.getExistingFontsByPostScriptName()

        let expectation = self.expectation(description: "Consistent reads under concurrency")
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "com.rokt.test.concurrent.consistent", attributes: .concurrent)
        let iterations = 200
        var results = [Bool](repeating: false, count: iterations)
        let resultsQueue = DispatchQueue(label: "com.rokt.test.results")

        for i in 0..<iterations {
            group.enter()
            queue.async {
                let result = FontManager.isSystemFont(font: FontModel(name: "ArialMT", url: ""))
                resultsQueue.sync { results[i] = result }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)
        XCTAssertTrue(results.allSatisfy { $0 }, "All concurrent reads of a known system font should return true")
    }
}
