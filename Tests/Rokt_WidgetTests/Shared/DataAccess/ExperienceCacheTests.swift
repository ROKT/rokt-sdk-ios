import XCTest
@testable import Rokt_Widget
@testable internal import RoktUXHelper

class ExperienceCacheTests: XCTestCase {
    private let mockedViewName = "test-view-name"
    private let mockedAttributes = ["email": "jenny.law@rokt.com",
                                    "confirmation": "123456"]
    private let mockedNonMatchingAttributes = ["email": "jenny.law@rokt.com",
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
    private static let testCacheDirectoryName = "test_RoktExperienceCache"

    static func prepareExperienceCacheTestFiles() {
        ExperienceCacheManager.setCacheDirectoryName(testCacheDirectoryName)
    }

    static func deleteExperienceCacheTestFiles() {
        ExperienceCacheManager.clearCache()
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
