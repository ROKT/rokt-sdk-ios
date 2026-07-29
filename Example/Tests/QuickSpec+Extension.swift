import Quick
import Foundation
@testable import Rokt_Widget

// MARK: Cache file utils

extension QuickSpec {
    func getJsonFileContents(_ fileName: String) -> String? {
        let path = Bundle(for: type(of: self)).path(forResource: fileName, ofType: "json")!
        return try? String(contentsOfFile: path)
    }

    /// The experience page the offers path renders for a v1 layout fixture: the
    /// fixture reshaped into the offers response, then adapted into the render
    /// contract. Mirrors what the offers service feeds the renderer, so cache
    /// assertions compare against the real output rather than the raw fixture.
    func expectedOffersPage(forV1Fixture fileName: String) -> String? {
        guard let path = Bundle(for: type(of: self)).path(forResource: fileName, ofType: "json"),
              let v1Data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let offersData = makeOffersData(fromV1Experience: v1Data),
              let response = try? JSONDecoder().decode(SelectResponse.self, from: offersData)
        else { return nil }
        return try? SelectExperienceAdapter.experienceJSONString(from: response)
    }

    func prepareExperienceCacheTestFiles(_ testCacheDirectoryName: String) {
        ExperienceCacheManager.setCacheDirectoryName(testCacheDirectoryName)
    }

    func deleteExperienceCacheTestFiles() {
        ExperienceCacheManager.clearCache()
    }
}
