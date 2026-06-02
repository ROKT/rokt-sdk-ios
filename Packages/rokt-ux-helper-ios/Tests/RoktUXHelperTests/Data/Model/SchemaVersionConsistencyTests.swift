import XCTest
@testable import RoktUXHelper

final class SchemaVersionConsistencyTests: XCTestCase {

    // Guards against drift between the dcui-swift-schema package version
    // pinned in Package.swift and Constants.layoutSchemaVersion reported in
    // RoktIntegrationInfo. Bumping one without the other has historically
    // gone unnoticed; this test forces both to move together.
    func test_layoutSchemaVersion_matches_dcuiSwiftSchemaPackageVersion() throws {
        let packageVersion = try readDcuiSwiftSchemaPinnedVersion()
        let reportedVersion = RoktIntegrationInfoDetails().layoutSchemaVersion

        XCTAssertEqual(
            reportedVersion,
            packageVersion,
            """
            Constants.layoutSchemaVersion (\(reportedVersion)) is out of sync with the \
            dcui-swift-schema version pinned in Package.swift (\(packageVersion)). \
            Update Constants.layoutSchemaVersion in RoktIntegrationInfoDetails.swift to match.
            """
        )
    }

    private func readDcuiSwiftSchemaPinnedVersion(file: StaticString = #filePath) throws -> String {
        let repoRoot = "\(file)".replacingOccurrences(
            of: #"/Tests/.*$"#,
            with: "",
            options: .regularExpression
        )
        let packageURL = URL(fileURLWithPath: repoRoot + "/Package.swift")

        let contents = try String(contentsOf: packageURL, encoding: .utf8)
        let pattern = #"dcui-swift-schema\.git",\s*exact:\s*"([^"]+)""#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(contents.startIndex..., in: contents)

        guard
            let match = regex.firstMatch(in: contents, range: range),
            let versionRange = Range(match.range(at: 1), in: contents)
        else {
            throw SchemaVersionLookupError.notFoundInPackageManifest(path: packageURL.path)
        }

        return String(contents[versionRange])
    }

    private enum SchemaVersionLookupError: Error, CustomStringConvertible {
        case notFoundInPackageManifest(path: String)

        var description: String {
            switch self {
            case .notFoundInPackageManifest(let path):
                return "Could not find dcui-swift-schema exact version in \(path)"
            }
        }
    }
}
