import XCTest
@testable import Rokt_Widget
@testable internal import RoktUXHelper

class ExperienceCacheTests: XCTestCase {
    private let mockedViewName = "test-view-name"
    private let mockedAttributes = ["email": "test1593754986316@rokt.com",
                                    "confirmation": "123456"]
    private let mockedNonMatchingAttributes = ["email": "test1593754986316@rokt.com",
                                               "confirmation": "123457"]
    private let mockedExperienceResponse = "experienceResponse"
    private let mockedPluginId = "plugin-id"

    private let mockedEventHash1: Set<String> = ["event", "hash", "1"]
    private let mockedEventHash2: Set<String> = ["event", "hash", "2"]

    override func setUp() {
        super.setUp()
        ExperienceCacheTests.prepareExperienceCacheTestFiles()
        ExperienceCacheTests.deleteExperienceCacheTestFiles()
    }

    override func tearDown() {
        ExperienceCacheTests.deleteExperienceCacheTestFiles()
        super.tearDown()
    }

    override func tearDownWithError() throws {
        ExperienceCacheTests.deleteExperienceCacheTestFiles()
        super.tearDown()
    }

    // MARK: Experience response cache management

    func testExperienceResponseCacheFileNameUsesCurrentResponseFormat() {
        let fileName = ExperienceCacheUtils.getExperienceResponseCacheFileName(
            viewName: mockedViewName,
            attributes: mockedAttributes
        )

        XCTAssertTrue(fileName.hasPrefix("RoktExperienceResponseV2"))
    }

    func test_cacheExperienceResponse_checkFileContents() {
        let mockedCachedDate = RoktSDKDateHandler.currentDate()
        ExperienceCacheManager.cacheExperienceResponse(viewName: mockedViewName,
                                                       attributes: mockedAttributes,
                                                       experienceResponse: mockedExperienceResponse)

        let exp = expectation(description: "Test after 1s")
        _ = XCTWaiter.wait(for: [exp], timeout: 1)

        XCTAssertTrue(ExperienceCacheTests.experienceCacheDirectoryExists())
        XCTAssertTrue(ExperienceCacheTests.experienceCacheFileExists(
            viewName: mockedViewName, attributes: mockedAttributes
        ))

        guard let fileData = ExperienceCacheManager.getCachedExperienceResponseFileData(
            viewName: mockedViewName,
            attributes: mockedAttributes
        )
        else {
            XCTFail("File data could not be read")
            return
        }

        do {
            let decodedData = try JSONDecoder().decode(
                ExperienceCacheUtils.ExperienceResponseFileData.self, from: fileData
            )
            XCTAssertEqual(decodedData.experienceResponse, mockedExperienceResponse)
            // Checks cachedTime in file is correctly set to approx. when set cache was called
            XCTAssertLessThan(decodedData.cachedTime.distance(to: mockedCachedDate), TimeInterval(1))
        } catch { XCTFail("File data could not be decoded") }
    }

    func test_cacheSubsequentExperienceResponse_checkFileReplaced() {
        // Set initial cache
        ExperienceCacheManager.cacheExperienceResponse(viewName: mockedViewName,
                                                       attributes: mockedAttributes,
                                                       experienceResponse: mockedExperienceResponse)

        let exp = expectation(description: "Test after 1s")
        _ = XCTWaiter.wait(for: [exp], timeout: 1)

        XCTAssertTrue(ExperienceCacheTests.experienceCacheDirectoryExists())
        XCTAssertTrue(ExperienceCacheTests.experienceCacheFileExists(
            viewName: mockedViewName, attributes: mockedAttributes
        ))

        // Set subsequent cache
        ExperienceCacheManager.cacheExperienceResponse(viewName: mockedViewName,
                                                       attributes: mockedNonMatchingAttributes,
                                                       experienceResponse: mockedExperienceResponse)

        let exp2 = expectation(description: "Test subsequent cache after 1s")
        _ = XCTWaiter.wait(for: [exp2], timeout: 1)

        XCTAssertFalse(ExperienceCacheTests.experienceCacheFileExists(
            viewName: mockedViewName, attributes: mockedAttributes
        ))
        XCTAssertTrue(ExperienceCacheTests.experienceCacheFileExists(
            viewName: mockedViewName, attributes: mockedNonMatchingAttributes
        ))
    }

    /// Caching a response must not take the view state with it: the plugin view states and
    /// sent-event hashes share that directory and are what the next execute restores. Deleting the
    /// directory to evict the previous response destroyed them, and because the delete is an async
    /// barrier while the view state is read straight off disk, it did so at a nondeterministic
    /// point — which is what made `uses cached plugin view states` fail on some runs and not others.
    func test_cacheExperienceResponse_evictsOnlyResponses_keepingViewState() {
        ExperienceCacheManager.updatePluginViewStateCache(
            viewName: mockedViewName,
            attributes: mockedAttributes,
            updateStates: RoktPluginViewState(pluginId: mockedPluginId, offerIndex: 4)
        )
        ExperienceCacheManager.cacheExperiencesViewStateSentEventHashes(
            viewName: mockedViewName,
            attributes: mockedAttributes,
            sentEventHashes: mockedEventHash1
        )
        // A superseded response, to prove eviction still happens.
        ExperienceCacheManager.cacheExperienceResponse(viewName: mockedViewName,
                                                       attributes: mockedNonMatchingAttributes,
                                                       experienceResponse: mockedExperienceResponse)

        let seeded = expectation(description: "Seeded cache after 1s")
        _ = XCTWaiter.wait(for: [seeded], timeout: 1)

        XCTAssertTrue(ExperienceCacheTests.experienceCachePluginViewStateFileExists(
            pluginId: mockedPluginId, viewName: mockedViewName, attributes: mockedAttributes
        ))

        ExperienceCacheManager.cacheExperienceResponse(viewName: mockedViewName,
                                                       attributes: mockedAttributes,
                                                       experienceResponse: mockedExperienceResponse)

        let cached = expectation(description: "Cached response after 1s")
        _ = XCTWaiter.wait(for: [cached], timeout: 1)

        // The new response is cached and the superseded one is gone.
        XCTAssertTrue(ExperienceCacheTests.experienceCacheFileExists(
            viewName: mockedViewName, attributes: mockedAttributes
        ))
        XCTAssertFalse(ExperienceCacheTests.experienceCacheFileExists(
            viewName: mockedViewName, attributes: mockedNonMatchingAttributes
        ))

        // The view state survived, contents intact.
        XCTAssertTrue(ExperienceCacheTests.experienceCachePluginViewStateFileExists(
            pluginId: mockedPluginId, viewName: mockedViewName, attributes: mockedAttributes
        ))
        XCTAssertTrue(ExperienceCacheTests.experienceCacheExperiencesViewStateFileExists(
            viewName: mockedViewName, attributes: mockedAttributes
        ))
        XCTAssertEqual(
            ExperienceCacheManager.getOrCreateCachedPluginViewState(
                pluginId: mockedPluginId, viewName: mockedViewName, attributes: mockedAttributes
            ),
            RoktPluginViewState(pluginId: mockedPluginId, offerIndex: 4, isPluginDismissed: false)
        )
        XCTAssertEqual(
            ExperienceCacheManager.getCachedExperiencesViewState(
                viewName: mockedViewName, attributes: mockedAttributes
            )?.sentEventHashes,
            mockedEventHash1
        )
    }

    /// The eviction scan and the write run inside one barrier on the cache's own queue: the call returns as soon as the
    /// barrier is queued, before the scan runs, and the scan runs off the calling thread.
    func test_cacheExperienceResponse_evictsAndWritesOnItsOwnQueue_notOnTheCaller() {
        let callReturned = DispatchSemaphore(value: 0)
        var evictionRanAfterCallReturned = false
        var evictionRanOnMainThread = true
        var evictionQueueLabel: String?
        ExperienceCacheManager.unitTest_duringResponseEviction = {
            evictionRanOnMainThread = Thread.isMainThread
            evictionQueueLabel = String(cString: __dispatch_queue_get_label(nil))
            // Holds the eviction until this thread has seen the call return: a call that ran the scan itself could
            // only return after this hold had timed out, and the flag would stay false.
            evictionRanAfterCallReturned = callReturned.wait(timeout: .now() + 1) == .success
        }
        addTeardownBlock { ExperienceCacheManager.unitTest_duringResponseEviction = nil }

        let written = expectation(description: "the response is written")
        ExperienceCacheManager.cacheExperienceResponse(viewName: mockedViewName,
                                                       attributes: mockedAttributes,
                                                       experienceResponse: mockedExperienceResponse,
                                                       success: { written.fulfill() })
        callReturned.signal()
        wait(for: [written], timeout: 5)

        XCTAssertTrue(evictionRanAfterCallReturned, "cacheExperienceResponse returns before the eviction scan runs")
        XCTAssertFalse(evictionRanOnMainThread, "the eviction scan does not run on the calling thread")
        XCTAssertEqual(evictionQueueLabel, ExperienceCacheManager.experienceCacheStorageQueueName)
        XCTAssertTrue(ExperienceCacheTests.experienceCacheFileExists(
            viewName: mockedViewName, attributes: mockedAttributes
        ))
    }

    func test_getCachedExperienceResponse_onEmptyCache_returnsNil() {
        let waitExp = expectation(description: "wait for clear to complete")
        _ = XCTWaiter.wait(for: [waitExp], timeout: 1)

        RoktSDKDateHandler.customDate = Date()
        let cachedExperienceResponse = ExperienceCacheManager.getCachedExperienceResponse(
            viewName: nil, attributes: [:], cacheDuration: TimeInterval(60)
        )

        XCTAssertFalse(ExperienceCacheTests.experienceCacheDirectoryExists())
        XCTAssertNil(cachedExperienceResponse)
    }

    func test_getCachedExperienceResponse_onValidMatchingCache_returnsExperienceResponse() {
        ExperienceCacheManager.cacheExperienceResponse(viewName: mockedViewName,
                                                       attributes: mockedAttributes,
                                                       experienceResponse: mockedExperienceResponse)

        let exp = expectation(description: "Test after 1s")
        _ = XCTWaiter.wait(for: [exp], timeout: 1)

        let cachedExperienceResponse = ExperienceCacheManager.getCachedExperienceResponse(
            viewName: mockedViewName,
            attributes: mockedAttributes,
            cacheDuration: TimeInterval(60)
        )

        XCTAssertTrue(ExperienceCacheTests.experienceCacheDirectoryExists())
        XCTAssertTrue(ExperienceCacheTests.experienceCacheFileExists(
            viewName: mockedViewName, attributes: mockedAttributes
        ))
        XCTAssertEqual(cachedExperienceResponse, mockedExperienceResponse)
    }

    func test_getCachedExperienceResponse_onNonMatchingCache_returnsNil() {
        ExperienceCacheManager.cacheExperienceResponse(viewName: mockedViewName,
                                                       attributes: mockedAttributes,
                                                       experienceResponse: mockedExperienceResponse)

        let exp = expectation(description: "Test after 1s")
        _ = XCTWaiter.wait(for: [exp], timeout: 1)

        let cachedExperienceResponse = ExperienceCacheManager.getCachedExperienceResponse(
            viewName: mockedViewName,
            attributes: mockedNonMatchingAttributes,
            cacheDuration: TimeInterval(60)
        )

        XCTAssertTrue(ExperienceCacheTests.experienceCacheDirectoryExists())
        XCTAssertTrue(ExperienceCacheTests.experienceCacheFileExists(
            viewName: mockedViewName, attributes: mockedAttributes
        ))
        XCTAssertNil(cachedExperienceResponse)
    }

    func test_getCachedExperienceResponse_onExpiredMatchingCache_returnsNil() {
        ExperienceCacheManager.cacheExperienceResponse(viewName: mockedViewName,
                                                       attributes: mockedAttributes,
                                                       experienceResponse: mockedExperienceResponse)

        let exp = expectation(description: "Test after 1s")
        _ = XCTWaiter.wait(for: [exp], timeout: 1)

        // Mock "current time" to after the expiry
        RoktSDKDateHandler.customDate = Date().addingTimeInterval(TimeInterval(61))

        let cachedExperienceResponse = ExperienceCacheManager.getCachedExperienceResponse(
            viewName: mockedViewName,
            attributes: mockedAttributes,
            cacheDuration: TimeInterval(60)
        )

        XCTAssertTrue(ExperienceCacheTests.experienceCacheDirectoryExists())
        XCTAssertTrue(ExperienceCacheTests.experienceCacheFileExists(
            viewName: mockedViewName, attributes: mockedAttributes
        ))
        XCTAssertNil(cachedExperienceResponse)
    }

    // MARK: Plugin view state cache management

    func test_getOrCreateCachePluginViewState_onEmpty_createsCachePluginViewState() {
        let pluginViewState = ExperienceCacheManager.getOrCreateCachedPluginViewState(
            pluginId: mockedPluginId,
            viewName: mockedViewName,
            attributes: mockedAttributes
        )

        let exp = expectation(description: "Test after 1s")
        _ = XCTWaiter.wait(for: [exp], timeout: 1)

        XCTAssertEqual(pluginViewState, RoktPluginViewState(pluginId: mockedPluginId))
        XCTAssertTrue(ExperienceCacheTests.experienceCacheDirectoryExists())
        XCTAssertTrue(ExperienceCacheTests.experienceCachePluginViewStateFileExists(
            pluginId: mockedPluginId, viewName: mockedViewName, attributes: mockedAttributes
        ))

        guard let fileData = ExperienceCacheManager.getCachedPluginViewStateFileData(
            pluginId: mockedPluginId, viewName: mockedViewName, attributes: mockedAttributes
        )
        else {
            XCTFail("File data could not be read")
            return
        }

        do {
            let decodedData = try JSONDecoder().decode(
                ExperienceCacheUtils.PluginViewStateFileData.self, from: fileData
            )

            XCTAssertEqual(decodedData.offerIndex, 0)
            XCTAssertEqual(decodedData.isPluginDismissed, false)
            XCTAssertEqual(decodedData.customStateMap, nil)
        } catch { XCTFail("File data could not be decoded") }
    }

    func test_updatePluginViewStateCache_checkFileContents() {
        // 1st update
        ExperienceCacheManager.updatePluginViewStateCache(
            viewName: mockedViewName,
            attributes: mockedAttributes,
            updateStates: RoktPluginViewState(pluginId: mockedPluginId,
                                              offerIndex: 4)
        )

        let exp = expectation(description: "Test after 1s")
        _ = XCTWaiter.wait(for: [exp], timeout: 1)

        XCTAssertTrue(ExperienceCacheTests.experienceCacheDirectoryExists())
        XCTAssertTrue(ExperienceCacheTests.experienceCachePluginViewStateFileExists(
            pluginId: mockedPluginId, viewName: mockedViewName, attributes: mockedAttributes
        ))

        guard let fileData = ExperienceCacheManager.getCachedPluginViewStateFileData(
            pluginId: mockedPluginId, viewName: mockedViewName, attributes: mockedAttributes
        )
        else {
            XCTFail("File data could not be read")
            return
        }

        do {
            let decodedData = try JSONDecoder().decode(
                ExperienceCacheUtils.PluginViewStateFileData.self, from: fileData
            )

            XCTAssertEqual(decodedData.offerIndex, 4)
            XCTAssertEqual(decodedData.isPluginDismissed, false)
            XCTAssertEqual(decodedData.customStateMap, nil)
        } catch { XCTFail("File data could not be decoded") }

        // 2nd update
        let customStateIdentifiable = CustomStateIdentifiable(position: 5, key: "state")
        let customStateMap = [customStateIdentifiable: 1]
        ExperienceCacheManager.updatePluginViewStateCache(
            viewName: mockedViewName,
            attributes: mockedAttributes,
            updateStates: RoktPluginViewState(pluginId: mockedPluginId,
                                              isPluginDismissed: true,
                                              customStateMap: customStateMap)
        )

        let exp2 = expectation(description: "Test after 1s")
        _ = XCTWaiter.wait(for: [exp2], timeout: 1)

        XCTAssertTrue(ExperienceCacheTests.experienceCacheDirectoryExists())
        XCTAssertTrue(ExperienceCacheTests.experienceCachePluginViewStateFileExists(
            pluginId: mockedPluginId, viewName: mockedViewName, attributes: mockedAttributes
        ))

        guard let fileData = ExperienceCacheManager.getCachedPluginViewStateFileData(
            pluginId: mockedPluginId, viewName: mockedViewName, attributes: mockedAttributes
        )
        else {
            XCTFail("File data could not be read")
            return
        }

        do {
            let decodedData = try JSONDecoder().decode(
                ExperienceCacheUtils.PluginViewStateFileData.self, from: fileData
            )

            XCTAssertEqual(decodedData.offerIndex, 4)
            XCTAssertEqual(decodedData.isPluginDismissed, true)
            XCTAssertEqual(decodedData.customStateMap, customStateMap)
        } catch { XCTFail("File data could not be decoded") }
    }

    // MARK: Plugin ids and file names stay inside the cache directory

    func test_getPluginViewStateFileName_hashesPluginId_soNoPathBytesReachTheFileName() {
        let prefix = "RoktPluginViewState"
        let pluginIdsWithPathCharacters = ["/../../x", "a/b\\c..d", "..", ""]
        var fileNames = Set<String>()

        for pluginId in pluginIdsWithPathCharacters {
            let fileName = pluginViewStateFileName(for: pluginId)

            XCTAssertTrue(fileName.hasPrefix(prefix), fileName)
            XCTAssertEqual(fileName.count, prefix.count + 128, fileName)
            XCTAssertNil(fileName.rangeOfCharacter(from: CharacterSet(charactersIn: "/\\.")), fileName)
            fileNames.insert(fileName)
        }

        XCTAssertEqual(fileNames.count, pluginIdsWithPathCharacters.count, "distinct plugin ids must map to distinct files")
        XCTAssertEqual(pluginViewStateFileName(for: mockedPluginId), pluginViewStateFileName(for: mockedPluginId))
    }

    func test_getFileUrl_rejectsNamesThatWouldLeaveTheCacheDirectory() throws {
        stubDiagnostics(onDiagnosticsReceive: { _ in })
        let cacheDirectory = try XCTUnwrap(ExperienceCacheManager.getCacheDirectoryUrl())

        for name in ["../../escape", "RoktPluginViewStateabc/../../escape", "/escape", "..", ".", "", "a\u{0}b"] {
            XCTAssertNil(ExperienceCacheManager.getFileUrl(name: name), "\(name.debugDescription) must not resolve")
        }

        let accepted = try XCTUnwrap(ExperienceCacheManager.getFileUrl(name: "RoktPluginViewStateabc"))
        XCTAssertEqual(accepted.lastPathComponent, "RoktPluginViewStateabc.json")
        XCTAssertTrue(accepted.isContained(in: cacheDirectory))
        XCTAssertTrue(accepted.path.hasPrefix(cacheDirectory.path + "/"))
    }

    func test_getOrCreateCachedPluginViewState_withTraversalPluginId_writesNothingOutsideTheCacheDirectory() throws {
        stubDiagnostics(onDiagnosticsReceive: { _ in })
        let fileManager = FileManager.default
        let cacheDirectory = try XCTUnwrap(ExperienceCacheManager.getCacheDirectoryUrl())
        let traversingPluginId = "/../../rokt-traversal-probe"
        // Where a verbatim id would have landed: the `..` segments collapse the whole
        // prefix+hash component, so any 64-character stand-in resolves to the same path.
        let escapedTarget = cacheDirectory
            .appendingPathComponent("RoktPluginViewState" + String(repeating: "0", count: 64) + traversingPluginId)
            .appendingPathExtension("json")
            .standardizedFileURL
        XCTAssertFalse(escapedTarget.isContained(in: cacheDirectory), "the probe must target a path outside the cache")
        try? fileManager.removeItem(at: escapedTarget)
        addTeardownBlock { try? fileManager.removeItem(at: escapedTarget) }

        _ = ExperienceCacheManager.getOrCreateCachedPluginViewState(
            pluginId: "/x", viewName: mockedViewName, attributes: mockedAttributes
        )
        let created = ExperienceCacheManager.getOrCreateCachedPluginViewState(
            pluginId: traversingPluginId, viewName: mockedViewName, attributes: mockedAttributes
        )

        let exp = expectation(description: "Test after 1s")
        _ = XCTWaiter.wait(for: [exp], timeout: 1)

        XCTAssertEqual(created, RoktPluginViewState(pluginId: traversingPluginId))
        XCTAssertFalse(fileManager.fileExists(atPath: escapedTarget.path), "plugin view state escaped the cache directory")
        XCTAssertTrue(ExperienceCacheTests.experienceCachePluginViewStateFileExists(
            pluginId: traversingPluginId, viewName: mockedViewName, attributes: mockedAttributes
        ), "the view state should still be cached, inside the cache directory")

        let contents = try XCTUnwrap(
            fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: nil)?.allObjects as? [URL]
        )
        XCTAssertFalse(contents.isEmpty)
        for item in contents {
            XCTAssertTrue(item.isContained(in: cacheDirectory), item.path)
        }
    }

    private func pluginViewStateFileName(for pluginId: String) -> String {
        ExperienceCacheUtils.getPluginViewStateFileName(
            pluginId: pluginId, viewName: mockedViewName, attributes: mockedAttributes
        )
    }

    // MARK: Experiences view state cache management

    func test_cacheExperienceViewState_checkFileContents() {
        ExperienceCacheManager.cacheExperiencesViewStateSentEventHashes(
            viewName: mockedViewName,
            attributes: mockedAttributes,
            sentEventHashes: mockedEventHash1
        )

        let exp = expectation(description: "Test after 1s")
        _ = XCTWaiter.wait(for: [exp], timeout: 1)

        XCTAssertTrue(ExperienceCacheTests.experienceCacheDirectoryExists())
        XCTAssertTrue(ExperienceCacheTests.experienceCacheExperiencesViewStateFileExists(
            viewName: mockedViewName, attributes: mockedAttributes
        ))

        guard let fileData = ExperienceCacheManager.getCachedExperiencesViewStateFileData(
            viewName: mockedViewName,
            attributes: mockedAttributes
        )
        else {
            XCTFail("File data could not be read")
            return
        }

        do {
            let decodedData = try JSONDecoder().decode(ExperiencesViewState.self, from: fileData)
            XCTAssertEqual(decodedData.sentEventHashes, mockedEventHash1)
        } catch { XCTFail("File data could not be decoded") }
    }

    func test_cacheSubsequentExperienceViewState_checkFileContentsUpdated() {
        // Set initial cache
        ExperienceCacheManager.cacheExperiencesViewStateSentEventHashes(
            viewName: mockedViewName,
            attributes: mockedAttributes,
            sentEventHashes: mockedEventHash1
        )

        let exp = expectation(description: "Test after 1s")
        _ = XCTWaiter.wait(for: [exp], timeout: 1)

        guard let fileData = ExperienceCacheManager.getCachedExperiencesViewStateFileData(
            viewName: mockedViewName,
            attributes: mockedAttributes
        )
        else {
            XCTFail("File data could not be read")
            return
        }

        do {
            let decodedData = try JSONDecoder().decode(ExperiencesViewState.self, from: fileData)
            XCTAssertEqual(decodedData.sentEventHashes, mockedEventHash1)
        } catch { XCTFail("File data could not be decoded") }

        // Add subsequent cache
        ExperienceCacheManager.cacheExperiencesViewStateSentEventHashes(
            viewName: mockedViewName,
            attributes: mockedAttributes,
            sentEventHashes: mockedEventHash2
        )

        let exp2 = expectation(description: "Test subsequent cache after 1s")
        _ = XCTWaiter.wait(for: [exp2], timeout: 1)

        guard let fileData = ExperienceCacheManager.getCachedExperiencesViewStateFileData(
            viewName: mockedViewName,
            attributes: mockedAttributes
        )
        else {
            XCTFail("File data could not be read")
            return
        }

        do {
            let decodedData = try JSONDecoder().decode(ExperiencesViewState.self, from: fileData)
            XCTAssertEqual(decodedData.sentEventHashes, mockedEventHash2)
        } catch { XCTFail("File data could not be decoded") }
    }

    func test_getCachedExperiencesViewState_onEmptyCache_returnsNil() {
        let cachedExperiencesViewState = ExperienceCacheManager.getCachedExperiencesViewState(viewName: mockedViewName,
                                                                                              attributes: mockedAttributes)
        XCTAssertNil(cachedExperiencesViewState)
    }

    func test_getCachedExperiencesViewState_onValidMatchingCache_returnsExperiencesViewState() {
        ExperienceCacheManager.cacheExperiencesViewStateSentEventHashes(
            viewName: mockedViewName,
            attributes: mockedAttributes,
            sentEventHashes: mockedEventHash1
        )

        let exp = expectation(description: "Test after 1s")
        _ = XCTWaiter.wait(for: [exp], timeout: 1)

        let cachedExperiencesViewState = ExperienceCacheManager.getCachedExperiencesViewState(
            viewName: mockedViewName,
            attributes: mockedAttributes
        )

        XCTAssertTrue(ExperienceCacheTests.experienceCacheDirectoryExists())
        XCTAssertTrue(ExperienceCacheTests.experienceCacheExperiencesViewStateFileExists(
            viewName: mockedViewName, attributes: mockedAttributes
        ))
        XCTAssertEqual(cachedExperiencesViewState?.sentEventHashes, mockedEventHash1)
    }

    func test_getCachedExperiencesViewState_onNonMatchingCache_returnsNil() {
        ExperienceCacheManager.cacheExperiencesViewStateSentEventHashes(
            viewName: mockedViewName,
            attributes: mockedAttributes,
            sentEventHashes: mockedEventHash1
        )

        let exp = expectation(description: "Test after 1s")
        _ = XCTWaiter.wait(for: [exp], timeout: 1)

        let cachedExperiencesViewState = ExperienceCacheManager.getCachedExperiencesViewState(
            viewName: mockedViewName,
            attributes: mockedNonMatchingAttributes
        )

        XCTAssertTrue(ExperienceCacheTests.experienceCacheDirectoryExists())
        XCTAssertTrue(ExperienceCacheTests.experienceCacheExperiencesViewStateFileExists(
            viewName: mockedViewName, attributes: mockedAttributes
        ))
        XCTAssertNil(cachedExperiencesViewState)
    }
}

extension XCTestCase {
    private static let testCacheDirectoryName =
        "test_RoktExperienceCache-\(ProcessInfo.processInfo.processIdentifier)"

    static func prepareExperienceCacheTestFiles() {
        ExperienceCacheManager.setCacheDirectoryName(testCacheDirectoryName)
    }

    static func deleteExperienceCacheTestFiles() {
        let completion = DispatchSemaphore(value: 0)
        ExperienceCacheManager.clearCache(
            success: { completion.signal() },
            failure: { completion.signal() }
        )
        _ = completion.wait(timeout: .now() + 5)
    }

    static func experienceCacheDirectoryExists() -> Bool {
        var isDirectory: ObjCBool = false
        guard let cacheDirectoryUrl = ExperienceCacheManager.getCacheDirectoryUrl() else {
            return false
        }
        let exists = FileManager.default.fileExists(atPath: cacheDirectoryUrl.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    static func experienceCacheFileExists(viewName: String, attributes: [String: String]) -> Bool {
        let fileName = ExperienceCacheUtils.getExperienceResponseCacheFileName(
            viewName: viewName,
            attributes: attributes
        )
        guard let fileURL = ExperienceCacheManager.getFileUrl(name: fileName) else {
            return false
        }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    static func experienceCachePluginViewStateFileExists(pluginId: String, viewName: String,
                                                         attributes: [String: String]) -> Bool {
        let fileName = ExperienceCacheUtils.getPluginViewStateFileName(
            pluginId: pluginId,
            viewName: viewName,
            attributes: attributes
        )
        guard let fileURL = ExperienceCacheManager.getFileUrl(name: fileName) else {
            return false
        }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    static func experienceCacheExperiencesViewStateFileExists(viewName: String, attributes: [String: String]) -> Bool {
        let fileName = ExperienceCacheUtils.getExperiencesViewStateFileName(
            viewName: viewName,
            attributes: attributes
        )
        guard let fileURL = ExperienceCacheManager.getFileUrl(name: fileName) else {
            return false
        }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
}
