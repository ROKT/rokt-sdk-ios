import Foundation

extension FileManager {
    static let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

    static let testDirectoryURL = temporaryDirectoryURL.appendingPathComponent("com.rokt.test.unit")

    @discardableResult
    static func createDirectoryAt(path: String) -> Bool {
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            return true
        } catch {
            return false
        }
    }

    static func temporaryFileURL() -> URL {
        FileManager.testDirectoryURL.appendingPathComponent(UUID().uuidString)
    }

    @discardableResult
    static func removeItem(atPath path: String) -> Bool {
        do {
            try FileManager.default.removeItem(atPath: path)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    static func removeItem(at url: URL) -> Bool {
        removeItem(atPath: url.path)
    }

    @discardableResult
    static func removeAllItemsInsideDirectory(atPath path: String) -> Bool {
        let enumerator = FileManager.default.enumerator(atPath: path)
        var result = true

        while let fileName = enumerator?.nextObject() as? String {
            let success = removeItem(atPath: path + "/\(fileName)")
            if !success { result = false }
        }

        return result
    }

    @discardableResult
    static func removeAllItemsInsideDirectory(url: URL) -> Bool {
        removeAllItemsInsideDirectory(atPath: url.path)
    }
}
