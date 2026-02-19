import Foundation

class FontRepository {
    // [`font_url`: [`font_name`: `font_save_date`]]
    typealias FontDetails = [String: [String: String]]
    typealias FontURLs = [String]

    static let fileStorageQueueName = "com.rokt.filemanagement.queue"

    private(set) static var fontDownloadURLFileName = "RoktFontDownloadedUrl"
    private(set) static var fontDownloadDetailFileName = "RoktFontDownloadedDetail"

    private static let fontDetailsSaveErrorPrefix = "Failed to save font details:"
    private static let fontDetailsLoadErrorPrefix = "Failed to load font details:"
    private static let fontDetailsDeleteErrorPrefix = "Failed to delete font details:"

    private static let fontURLSaveErrorPrefix = "Failed to save font urls:"
    private static let fontURLLoadErrorPrefix = "Failed to load font urls:"
    private static let fontURLDeleteErrorPrefix = "Failed to delete font urls:"

    static let shared = FontRepository()
    private let fileStorage: ConcurrentQueueFileStorageDecorator
    private static var backingStore: ConcurrentQueueFileStorageDecorator { FontRepository.shared.fileStorage }

    private init() {
        fileStorage = ConcurrentQueueFileStorageDecorator(
            queueName: FontRepository.fileStorageQueueName,
            decoratee: JSONBackingStore()
        )
    }

    // MARK: - Font URLs - array of registered [`font_url`]

    /// Saves a font URL atomically using read-modify-write pattern.
    /// This prevents race conditions when multiple fonts are saved concurrently.
    static func saveFontUrl(key: String, completion: (() -> Void)? = nil) {
        guard let fileURL = getFileUrl(name: fontDownloadURLFileName) else { return }

        backingStore.atomicReadModifyWrite(
            url: fileURL,
            defaultValue: FontURLs()
        ) { (currentURLs: FontURLs) -> FontURLs in
            var urls = currentURLs
            urls.addIfNotExists(key)
            return urls
        } completion: { result in
            switch result {
            case .success:
                completion?()
            case .failure(let error):
                sendDiagnosticWith(prefix: fontURLSaveErrorPrefix, error: error)
            }
        }
    }

    /// Removes a font URL atomically using read-modify-write pattern.
    static func removeFontUrl(key: String, completion: (() -> Void)? = nil) {
        guard let fileURL = getFileUrl(name: fontDownloadURLFileName) else { return }

        backingStore.atomicReadModifyWrite(
            url: fileURL,
            defaultValue: FontURLs()
        ) { (currentURLs: FontURLs) -> FontURLs in
            var urls = currentURLs
            if let indexOfKey = urls.firstIndex(of: key) {
                urls.remove(at: indexOfKey)
            }
            return urls
        } completion: { result in
            switch result {
            case .success:
                completion?()
            case .failure(let error):
                sendDiagnosticWith(prefix: fontURLDeleteErrorPrefix, error: error)
            }
        }
    }

    static func loadAllFontURLs() -> FontURLs? {
        guard let fileURL = getFileUrl(name: fontDownloadURLFileName) else { return nil }

        // Use the backing store's synchronized read - it handles file-not-found gracefully
        let decodedFileContents: [String]? = backingStore.contentsOfFileAt(url: fileURL) { result in
            if case .failure(let error) = result {
                // Only send diagnostics for real errors, not "file doesn't exist"
                if !isFileNotFoundError(error) {
                    sendDiagnosticWith(prefix: fontURLLoadErrorPrefix, error: error)
                }
            }
        }

        return decodedFileContents
    }

    // MARK: - Font Details

    // FontDetails is a dictionary containing registered font urls and their registration names
    // [`font_url`: [`font_name`: `font_save_date`]]

    /// Saves font details atomically using read-modify-write pattern.
    static func saveFontDetail(
        key: String,
        values: [String: String],
        completion: (() -> Void)? = nil
    ) {
        guard let fileURL = getFileUrl(name: fontDownloadDetailFileName) else { return }

        backingStore.atomicReadModifyWrite(
            url: fileURL,
            defaultValue: FontDetails()
        ) { (currentDetails: FontDetails) -> FontDetails in
            var details = currentDetails
            details[key] = values
            return details
        } completion: { result in
            switch result {
            case .success:
                completion?()
            case .failure(let error):
                sendDiagnosticWith(prefix: fontDetailsSaveErrorPrefix, error: error)
            }
        }
    }

    /// Removes font details atomically using read-modify-write pattern.
    static func removeFontDetail(key: String, completion: (() -> Void)? = nil) {
        guard let fileURL = getFileUrl(name: fontDownloadDetailFileName) else { return }

        backingStore.atomicReadModifyWrite(
            url: fileURL,
            defaultValue: FontDetails()
        ) { (currentDetails: FontDetails) -> FontDetails in
            var details = currentDetails
            details.removeValue(forKey: key)
            return details
        } completion: { result in
            switch result {
            case .success:
                completion?()
            case .failure(let error):
                sendDiagnosticWith(prefix: fontDetailsDeleteErrorPrefix, error: error)
            }
        }
    }

    private static func loadAllFontDetails() -> FontDetails {
        guard let fileURL = getFileUrl(name: fontDownloadDetailFileName) else { return [:] }

        // Use the backing store's synchronized read - it handles file-not-found gracefully
        let decodedFileContents: FontDetails? = backingStore.contentsOfFileAt(url: fileURL) { result in
            if case .failure(let error) = result {
                // Only send diagnostics for real errors, not "file doesn't exist"
                if !isFileNotFoundError(error) {
                    sendDiagnosticWith(prefix: fontDetailsLoadErrorPrefix, error: error)
                }
            }
        }

        return decodedFileContents ?? [:]
    }

    static func loadFontDetail(key: String) -> [String: String]? {
        loadAllFontDetails()[key]
    }

    // MARK: - Error handling

    /// Checks if the error indicates that the file simply doesn't exist (cache miss).
    /// This is a normal condition, not an error that should be reported.
    private static func isFileNotFoundError(_ error: Error) -> Bool {
        if let roktError = error as? RoktError {
            return roktError.errorDescription == "File does not exist"
        }
        return false
    }

    // MARK: - Diagnostics

    private static func sendDiagnosticWith(prefix: String, error: Error) {
        RoktAPIHelper.sendDiagnostics(
            message: kAPIFontErrorCode,
            callStack: "\(prefix) \(error.localizedDescription)"
        )
    }

    // MARK: - FileName management

    static func setFontDownloadURLFileName(_ fileName: String) {
        fontDownloadURLFileName = fileName
    }

    static func setFontDownloadDetailFileName(_ fileName: String) {
        fontDownloadDetailFileName = fileName
    }

    internal static func getFileUrl(name: String) -> URL? {
        if let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fullPath = documentsUrl.appendingPathComponent(name).appendingPathExtension("json")
            return fullPath
        }
        return nil
    }

    internal static func isFileExist(name: String) -> Bool {
        guard let fileURL = getFileUrl(name: name) else { return false }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
}

internal extension RangeReplaceableCollection where Element: Equatable {
    mutating func addIfNotExists(_ element: Element) {
        if let index = firstIndex(of: element) {
            remove(at: index)
        }
        insert(element, at: startIndex)
    }
}
