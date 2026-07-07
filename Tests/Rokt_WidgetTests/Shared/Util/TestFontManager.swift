import XCTest
@testable import Rokt_Widget

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
        let cacheDirectoryUrl = try XCTUnwrap(FontRepository.getCacheDirectoryUrl())
        let expectedURL = cacheDirectoryUrl.appendingPathComponent("test.ttf")

        let url = try XCTUnwrap(FontManager.getFileUrl(name: "test"))

        XCTAssertEqual(url, expectedURL)
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
