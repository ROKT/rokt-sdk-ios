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
                completion?()
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
                completion?()
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
                completion?()
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
                completion?()
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

    private static func sendDiagnosticWith(prefix: String, error: Error, severity: Severity = .info) {
        RoktAPIHelper.sendDiagnostics(
            message: fontDiagnosticCode,
            callStack: "\(prefix) \(error.localizedDescription)",
            severity: severity
        )
    }

    // MARK: - FileName management

    static func setFontDownloadURLFileName(_ fileName: String) {
        fontDownloadURLFileName = fileName
    }

    static func setFontDownloadDetailFileName(_ fileName: String) {
        fontDownloadDetailFileName = fileName
    }

    // MARK: - Font directory (Application Support)

    static let fontDirectoryName = "RoktFonts"
    private static let migrationMarkerFileName = ".rokt_font_storage_application_support"
    private static let productionFontURLMetadataFileName = "RoktFontDownloadedUrl.json"
    private static let productionFontDetailMetadataFileName = "RoktFontDownloadedDetail.json"

    private static let migrationLock = NSLock()

    /// Directory used for font binaries and metadata. Application Support is durable
    /// (unlike Caches) while remaining outside Documents.
    internal static func getFontDirectoryUrl(fileManager: FileManager = .default) -> URL? {
        guard let supportUrl = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let fullPath: URL
        if #available(iOS 16.0, *) {
            fullPath = supportUrl.appending(component: fontDirectoryName, directoryHint: .isDirectory)
        } else {
            fullPath = supportUrl.appendingPathComponent(fontDirectoryName, isDirectory: true)
        }

        return fullPath
    }

    /// Moves leftover fonts/metadata from Documents (pre-5.2.6) and Caches/RoktFonts
    /// (5.2.6+) into Application Support once per install.
    internal static func migrateLegacyFontStorageIfNeeded(fileManager: FileManager = .default) {
        migrationLock.lock()
        defer { migrationLock.unlock() }

        guard let destination = getFontDirectoryUrl(fileManager: fileManager) else { return }

        let markerURL = destination.appendingPathComponent(migrationMarkerFileName)
        if fileManager.fileExists(atPath: markerURL.path) {
            return
        }

        do {
            try fileManager.createDirectory(
                at: destination,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
        } catch {
            return
        }

        if let cachesRoot = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let legacyCaches = cachesRoot.appendingPathComponent(fontDirectoryName, isDirectory: true)
            migrateDirectoryContents(from: legacyCaches, to: destination, fileManager: fileManager)
            removeDirectoryIfEmpty(legacyCaches, fileManager: fileManager)
        }

        if let documentsRoot = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            migrateDocumentsLegacyFonts(from: documentsRoot, to: destination, fileManager: fileManager)
        }

        try? Data().write(to: markerURL, options: .atomic)
    }

    // periphery:ignore - used by tests
    /// Test seam to re-run migration against a clean destination marker.
    internal static func resetMigrationMarkerForTests(fileManager: FileManager = .default) {
        migrationLock.lock()
        defer { migrationLock.unlock() }

        guard let destination = getFontDirectoryUrl(fileManager: fileManager) else { return }
        let markerURL = destination.appendingPathComponent(migrationMarkerFileName)
        try? fileManager.removeItem(at: markerURL)
    }

    private static func migrateDocumentsLegacyFonts(
        from documentsRoot: URL,
        to destination: URL,
        fileManager: FileManager
    ) {
        migrateFileIfNeeded(
            from: documentsRoot.appendingPathComponent(productionFontURLMetadataFileName),
            to: destination.appendingPathComponent(productionFontURLMetadataFileName),
            fileManager: fileManager
        )
        migrateFileIfNeeded(
            from: documentsRoot.appendingPathComponent(productionFontDetailMetadataFileName),
            to: destination.appendingPathComponent(productionFontDetailMetadataFileName),
            fileManager: fileManager
        )

        let detailURL = destination.appendingPathComponent(productionFontDetailMetadataFileName)
        guard fileManager.fileExists(atPath: detailURL.path),
              let data = try? Data(contentsOf: detailURL),
              let details = try? JSONDecoder().decode(FontDetails.self, from: data)
        else {
            return
        }

        let fontNames = Set(details.values.compactMap { $0["name"] })
        for fontName in fontNames {
            let fileName = "\(fontName).ttf"
            migrateFileIfNeeded(
                from: documentsRoot.appendingPathComponent(fileName),
                to: destination.appendingPathComponent(fileName),
                fileManager: fileManager
            )
        }
    }

    private static func migrateDirectoryContents(
        from source: URL,
        to destination: URL,
        fileManager: FileManager
    ) {
        guard fileManager.fileExists(atPath: source.path),
              let items = try? fileManager.contentsOfDirectory(
                  at: source,
                  includingPropertiesForKeys: nil,
                  options: [.skipsHiddenFiles]
              )
        else {
            return
        }

        for item in items {
            migrateFileIfNeeded(
                from: item,
                to: destination.appendingPathComponent(item.lastPathComponent),
                fileManager: fileManager
            )
        }
    }

    private static func migrateFileIfNeeded(from source: URL, to destination: URL, fileManager: FileManager) {
        guard fileManager.fileExists(atPath: source.path) else { return }

        if fileManager.fileExists(atPath: destination.path) {
            try? fileManager.removeItem(at: source)
            return
        }

        do {
            try fileManager.moveItem(at: source, to: destination)
        } catch {
            do {
                try fileManager.copyItem(at: source, to: destination)
                try? fileManager.removeItem(at: source)
            } catch {
                // Best-effort: leave the source in place if neither move nor copy succeeds.
            }
        }
    }

    private static func removeDirectoryIfEmpty(_ directory: URL, fileManager: FileManager) {
        guard fileManager.fileExists(atPath: directory.path),
              let remaining = try? fileManager.contentsOfDirectory(atPath: directory.path),
              remaining.isEmpty
        else {
            return
        }
        try? fileManager.removeItem(at: directory)
    }

    internal static func getFileUrl(name: String) -> URL? {
        guard let fontDirectoryUrl = getFontDirectoryUrl() else { return nil }
        return fontDirectoryUrl.appendingPathComponent(name).appendingPathExtension("json")
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
