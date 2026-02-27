import Foundation
internal import RoktUXHelper

internal class ExperienceCacheManager {

    static let shared = ExperienceCacheManager()
    static let experienceCacheStorageQueueName = "com.rokt.experiencecachestorage.queue"
    private(set) static var cacheDirectory = "RoktExperienceCache"
    private let fileStorage: FileStorage
    private static var backingStore: FileStorage { ExperienceCacheManager.shared.fileStorage }

    private init() {
        fileStorage = ConcurrentQueueFileStorageDecorator(
            queueName: ExperienceCacheManager.experienceCacheStorageQueueName,
            decoratee: JSONBackingStore())
    }

    // MARK: Experience response cache management

    /**
     Retrieve existing cached experience response if it exists and cache is still valid

     - Parameters:
      - viewName: A string representing the targetted view name received in execute.
      - attributes: A string dictionary containing the custom attributes received in execute.
      - cacheDuration: A TimeInterval of how long cache is valid for (TTL)
     */
    static func getCachedExperienceResponse(viewName: String?,
                                            attributes: [String: String],
                                            cacheDuration: TimeInterval) -> String? {
        guard let fileData = getCachedExperienceResponseFileData(
            viewName: viewName,
            attributes: attributes) else { return nil }
        return ExperienceCacheUtils.getValidExperienceResponse(data: fileData, cacheDuration: cacheDuration)
    }

    /**
     Clear existing cache and save new experience response in cache

     - Parameters:
      - viewName: A string representing the targetted view name received in execute.
      - attributes: A string dictionary containing the custom attributes received in execute.
      - experienceResponse: String representation of entire experience response to be cached.
      - success: Callback on success of saving new experience response in cache.
      - failure: Callback on any failure on attempt to save new experience response in cache.
     */
    static func cacheExperienceResponse(
        viewName: String?,
        attributes: [String: String],
        experienceResponse: String,
        success: (() -> Void)? = nil,
        failure: (() -> Void)? = nil
    ) {
        clearCache(
            success: {
                let fileName = ExperienceCacheUtils.getExperienceResponseCacheFileName(
                    viewName: viewName,
                    attributes: attributes)
                guard let fileURL = getFileUrl(name: fileName) else {
                    failure?()
                    return
                }

                guard let fileContents = ExperienceCacheUtils.generateExperienceResponseCacheFileContent(
                    experienceResponse: experienceResponse) else {
                    failure?()
                    return
                }

                saveToFile(
                    data: fileContents,
                    to: fileURL,
                    success: success,
                    failure: failure)
            }, failure: {
                failure?()
            })
    }

    static func getCachedExperienceResponseFileData(viewName: String?,
                                                    attributes: [String: String]) -> Data? {
        let fileName = ExperienceCacheUtils.getExperienceResponseCacheFileName(
            viewName: viewName,
            attributes: attributes)
        guard let fileUrl = getFileUrl(name: fileName) else { return nil }
        do {
            return try Data(contentsOf: fileUrl, options: .mappedIfSafe)
        } catch {
            return nil
        }
    }

    // MARK: Plugin view state cache management

    /**
     Retrieve existing cached plugin view state if it exists. Create if not

     - Parameters:
      - pluginId: A string representing the plugin ID
      - viewName: A string representing the targetted view name received in execute.
      - attributes: A string dictionary containing the custom attributes received in execute.

     */
    static func getOrCreateCachedPluginViewState(pluginId: String,
                                                 viewName: String?,
                                                 attributes: [String: String]) -> RoktPluginViewState {
        if let fileData = getCachedPluginViewStateFileData(pluginId: pluginId, viewName: viewName, attributes: attributes),
           let validPluginViewState = ExperienceCacheUtils.getValidPluginViewState(pluginId: pluginId, data: fileData) {
            return validPluginViewState
        } else {
            return createPluginViewStateCache(pluginId: pluginId, viewName: viewName, attributes: attributes)
        }

    }

    /**
     Cache new view state for a plugin

     - Parameters:
      - viewName: A string representing the targetted view name received in execute.
      - attributes: A string dictionary containing the custom attributes received in execute.
      - pluginId: A string representing the plugin ID
     */
    private static func createPluginViewStateCache(
        pluginId: String,
        viewName: String?,
        attributes: [String: String]
    ) -> RoktPluginViewState {

        let pluginViewState = RoktPluginViewState(pluginId: pluginId)
        cachePluginViewState(viewName: viewName, attributes: attributes, pluginViewState: pluginViewState)
        return pluginViewState
    }

    /**
     Update latest view state for a plugin in cache

     - Parameters:
      - viewName: A string representing the targetted view name received in execute.
      - attributes: A string dictionary containing the custom attributes received in execute.
      - pluginViewStateUpdates: RoktPluginViewStateUpdates of all properties to be updated.
     */
    static func updatePluginViewStateCache(
        viewName: String?,
        attributes: [String: String],
        updateStates: RoktPluginViewState
    ) {

        let cached = getOrCreateCachedPluginViewState(pluginId: updateStates.pluginId,
                                                      viewName: viewName,
                                                      attributes: attributes)

        let pluginViewState = RoktPluginViewState(pluginId: updateStates.pluginId,
                                                  offerIndex: updateStates.offerIndex ?? cached.offerIndex,
                                                  isPluginDismissed: updateStates.isPluginDismissed ?? cached.isPluginDismissed,
                                                  customStateMap: updateStates.customStateMap ?? cached.customStateMap)
        cachePluginViewState(viewName: viewName, attributes: attributes, pluginViewState: pluginViewState)
    }

    /**
     Save given view state for a plugin in cache

     - Parameters:
      - viewName: A string representing the targetted view name received in execute.
      - attributes: A string dictionary containing the custom attributes received in execute.
      - pluginViewState: RoktPluginViewState object storing latest view state for a plugin
     */
    private static func cachePluginViewState(
        viewName: String?,
        attributes: [String: String],
        pluginViewState: RoktPluginViewState
    ) {
        let fileName = ExperienceCacheUtils.getPluginViewStateFileName(
            pluginId: pluginViewState.pluginId,
            viewName: viewName,
            attributes: attributes)
        guard let fileURL = getFileUrl(name: fileName) else {
            return
        }

        let fileContents = ExperienceCacheUtils.generatePluginViewStateCacheFileContent(
            pluginViewState: pluginViewState)

        saveToFile(
            data: fileContents,
            to: fileURL)
    }

    static func getCachedPluginViewStateFileData(pluginId: String,
                                                 viewName: String?,
                                                 attributes: [String: String]) -> Data? {
        let fileName = ExperienceCacheUtils.getPluginViewStateFileName(
            pluginId: pluginId, viewName: viewName, attributes: attributes)
        guard let fileUrl = getFileUrl(name: fileName) else { return nil }
        do {
            return try Data(contentsOf: fileUrl, options: .mappedIfSafe)
        } catch {
            return nil
        }
    }

    // MARK: Experiences view state cache management

    /**
     Retrieve existing cached experiences view state if it exists and valid

     - Parameters:
      - viewName: A string representing the targetted view name received in execute.
      - attributes: A string dictionary containing the custom attributes received in execute.
     */
    static func getCachedExperiencesViewState(viewName: String?,
                                              attributes: [String: String]) -> ExperiencesViewState? {
        guard let fileData = getCachedExperiencesViewStateFileData(
            viewName: viewName,
            attributes: attributes) else { return nil }
        return ExperienceCacheUtils.getValidExperiencesViewState(data: fileData)
    }

    /**
     Update sentEventHashes in experiences view state by adding new event hashes

     - Parameters:
      - viewName: A string representing the targetted view name received in execute.
      - attributes: A string dictionary containing the custom attributes received in execute.
      - eventHashes: Set of event hashes to be added to cache.
     */
    static func cacheExperiencesViewStateSentEventHashes(
        viewName: String?,
        attributes: [String: String],
        sentEventHashes: Set<String>
    ) {
        let experiencesViewState = ExperiencesViewState(sentEventHashes: sentEventHashes)
        cacheExperiencesViewState(viewName: viewName, attributes: attributes, experiencesViewState: experiencesViewState)
    }

    /**
     Save given experiences view state in cache

     - Parameters:
      - viewName: A string representing the targetted view name received in execute.
      - attributes: A string dictionary containing the custom attributes received in execute.
      - experiencesViewState: ExperiencesViewState object storing latest view state for the experience
     */
    private static func cacheExperiencesViewState(
        viewName: String?,
        attributes: [String: String],
        experiencesViewState: ExperiencesViewState
    ) {
        let fileName = ExperienceCacheUtils.getExperiencesViewStateFileName(
            viewName: viewName, attributes: attributes)
        guard let fileURL = getFileUrl(name: fileName) else {
            return
        }

        let fileContents = ExperienceCacheUtils.generateExperiencesViewStateCacheFileContent(
            experiencesViewState: experiencesViewState)

        saveToFile(
            data: fileContents,
            to: fileURL)
    }

    static func getCachedExperiencesViewStateFileData(viewName: String?,
                                                      attributes: [String: String]) -> Data? {
        let fileName = ExperienceCacheUtils.getExperiencesViewStateFileName(viewName: viewName, attributes: attributes)
        guard let fileUrl = getFileUrl(name: fileName) else { return nil }
        do {
            return try Data(contentsOf: fileUrl, options: .mappedIfSafe)
        } catch {
            return nil
        }
    }

    // MARK: - File write

    static func clearCache(success: (() -> Void)? = nil,
                           failure: (() -> Void)? = nil) {
        guard let cacheDirectoryUrl = getCacheDirectoryUrl() else {
            failure?()
            return
        }
        backingStore.deleteFileAtUrl(at: cacheDirectoryUrl) { result in
            switch result {
            case .success:
                success?()
            case .failure:
                failure?()
            }
        }
    }

    private static func saveToFile<T: Encodable>(
        data: T,
        to fileURL: URL,
        success: (() -> Void)? = nil,
        failure: (() -> Void)? = nil
    ) {
        backingStore.write(payload: data, to: fileURL,
                           options: [.createIntermediateDirectories]) { result in
            switch result {
            case .success:
                success?()
            case .failure:
                failure?()
            }
        }
    }

    static func getFileUrl(name: String) -> URL? {
        guard let cachesDirectoryUrl = getCacheDirectoryUrl() else { return nil }
        return cachesDirectoryUrl.appendingPathComponent(name).appendingPathExtension("json")
    }

    static func getCacheDirectoryUrl() -> URL? {
        if let cachesUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            var fullPath: URL
            if #available(iOS 16.0, *) {
                fullPath = cachesUrl.appending(component: cacheDirectory, directoryHint: .isDirectory)
            } else {
                fullPath = cachesUrl.appendingPathComponent(cacheDirectory, isDirectory: true)
            }
            return fullPath
        }
        return nil
    }

    // MARK: - Cache directory name management

    static func setCacheDirectoryName(_ dirName: String) {
        cacheDirectory = dirName
    }
}
