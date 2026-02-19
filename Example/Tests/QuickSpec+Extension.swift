import Quick
import Foundation
@testable import Rokt_Widget

// MARK: Cache file utils

extension QuickSpec {
    func getJsonFileContents(_ fileName: String) -> String? {
        let path = Bundle(for: type(of: self)).path(forResource: fileName, ofType: "json")!
        return try? String(contentsOfFile: path)
    }

    func prepareExperienceCacheTestFiles(_ testCacheDirectoryName: String) {
        ExperienceCacheManager.setCacheDirectoryName(testCacheDirectoryName)
    }

    func deleteExperienceCacheTestFiles() {
        ExperienceCacheManager.clearCache()
    }
}
