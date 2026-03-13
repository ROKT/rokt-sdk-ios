import Foundation
internal import RoktUXHelper

struct ExperienceCacheUtils {

    struct ExperienceResponseFileData: Codable {
        let experienceResponse: String
        let cachedTime: Date
    }

    struct PluginViewStateFileData: Codable {
        let offerIndex: Int?
        let isPluginDismissed: Bool?
        let customStateMap: RoktUXCustomStateMap?
    }

    private static let experienceResponseFilePrefix = "RoktExperienceResponse"
    private static let viewStateFilePrefix = "RoktPluginViewState"
    private static let experiencesViewStateFilePrefix = "RoktExperiencesViewState"

    private static let experienceResponseJsonKey = "experienceResponse"
    private static let cacheExpiryJsonKey = "cacheExpiry"

    // MARK: Experience response

    /**
     Compute and return experience response full file name

     - Parameters:
      - viewName: A string representing the targetted view name received in execute.
      - attributes: A string dictionary containing the custom attributes received in execute.
     */
    static func getExperienceResponseCacheFileName(viewName: String?,
                                                   attributes: [String: String]) -> String {
        let hashKey = getExperienceCacheHashKey(viewName: viewName, attributes: attributes)
        return String(format: "%@%@", experienceResponseFilePrefix, hashKey)
    }

    /**
     Generate and return full contents to be written to experience response cache file. This consists of the experience response and cache expiry.

     - Parameters:
      - experienceResponse: A string of the entire experience response.
     */
    static func generateExperienceResponseCacheFileContent(experienceResponse: String) -> ExperienceResponseFileData? {
        return ExperienceResponseFileData(experienceResponse: experienceResponse,
                                          cachedTime: RoktSDKDateHandler.currentDate())
    }

    /**
     Get experience response from raw, existing experience response cache file content if file contents are in the correct format and cache is not expired.

     - Parameters:
      - fileContent: [String]? Undecoded raw file content
     */
    static func getValidExperienceResponse(data: Data, cacheDuration: TimeInterval) -> String? {
        do {
            let decodedData = try JSONDecoder().decode(ExperienceResponseFileData.self, from: data)
            if RoktSDKDateHandler.currentDate() < decodedData.cachedTime.advanced(by: cacheDuration) {
                return decodedData.experienceResponse
            }
        } catch {
            return nil
        }
        return nil
    }

    // MARK: Plugin view state

    /**
     Generate and return full contents to be written to plugin view state cache file.

     - Parameters:
      - pluginViewState: RoktPluginViewState object storing latest view state for a plugin, to be written to file
     */
    static func generatePluginViewStateCacheFileContent(pluginViewState: RoktPluginViewState) -> PluginViewStateFileData {
        return PluginViewStateFileData(offerIndex: pluginViewState.offerIndex,
                                       isPluginDismissed: pluginViewState.isPluginDismissed,
                                       customStateMap: pluginViewState.customStateMap)
    }

    /**
     Get plugin view state from raw, existing plugin view state cache file content if file contents are in the correct format

     - Parameters:
      - data: Undecoded raw file content of type Data
     */
    static func getValidPluginViewState(pluginId: String, data: Data) -> RoktPluginViewState? {
        do {
            let decodedData = try JSONDecoder().decode(PluginViewStateFileData.self, from: data)
            return RoktPluginViewState(
                pluginId: pluginId,
                offerIndex: decodedData.offerIndex,
                isPluginDismissed: decodedData.isPluginDismissed,
                customStateMap: decodedData.customStateMap
            )
        } catch {
            return nil
        }
    }

    /**
     Compute and return plugin view state full file name

     - Parameters:
      - pluginId: A string representing the plugin ID
      - viewName: A string representing the targetted view name received in execute.
      - attributes: A string dictionary containing the custom attributes received in execute.
     */
    static func getPluginViewStateFileName(pluginId: String,
                                           viewName: String?,
                                           attributes: [String: String]) -> String {
        let hashKey = getExperienceCacheHashKey(viewName: viewName, attributes: attributes)
        return String(format: "%@%@%@", viewStateFilePrefix, hashKey, pluginId)
    }

    // MARK: Experiences view state

    /**
     Compute and return experiences view state full file name

     - Parameters:
      - viewName: A string representing the targetted view name received in execute.
      - attributes: A string dictionary containing the custom attributes received in execute.
     */
    static func getExperiencesViewStateFileName(viewName: String?,
                                                attributes: [String: String]) -> String {
        let hashKey = getExperienceCacheHashKey(viewName: viewName, attributes: attributes)
        return String(format: "%@%@", experiencesViewStateFilePrefix, hashKey)
    }

    /**
     Generate and return full contents to be written to experiences view state cache file.

     - Parameters:
      - experiencesViewState: ExperiencesViewState object, storing latest view state for the experience, to be written to file
     */
    static func generateExperiencesViewStateCacheFileContent(
        experiencesViewState: ExperiencesViewState
    ) -> ExperiencesViewState? {
        return ExperiencesViewState(sentEventHashes: experiencesViewState.sentEventHashes)
    }

    /**
     Get experience response from raw, existing experience view state cache file content if file contents are in the correct format.

     - Parameters:
      - data: [String]? Undecoded raw file content
     */
    static func getValidExperiencesViewState(data: Data) -> ExperiencesViewState? {
        do {
            let decodedData = try JSONDecoder().decode(ExperiencesViewState.self, from: data)
            return ExperiencesViewState(sentEventHashes: decodedData.sentEventHashes)
        } catch {
            return nil
        }
    }

    /**
     Compute and return experience cache hash key

     - Parameters:
      - viewName: A string representing the targetted view name received in execute.
      - attributes: A string dictionary containing the custom attributes received in execute.
     */
    private static func getExperienceCacheHashKey(viewName: String?,
                                                  attributes: [String: String]) -> String {
        let attributesString = attributes.sorted(by: { $0.0 < $1.0 }).map { "\($0):\($1)" }.joined(separator: "")
        return (viewName ?? "").appending(attributesString).sha256()
    }
}
