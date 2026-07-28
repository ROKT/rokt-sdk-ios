import Foundation
import UIKit

internal class FontManager {
    private static let registerGraphicsFontErrorMsg = "font: %@, error: registerGraphicsFont on device %@"
    private static let registerUrlFontErrorMsg = "font: %@, error: registerURLFont on device %@"
    static let logFontPreloadedType = "pre-loaded"
    private static let logFontDownloadedType = "downloaded"
    static let downloadingFonts = "downloadingFonts"
    private static let fullFontLogDiagnosticCode = "[FULLFONTLOGS]"
    private static let fullFontLogCode1 = "[FFL001]"
    private static let fullFontLogCode5 = "[FFL005]"
    private static let fullFontLogCode6 = "[FFL006]"
    private static let fullFontLogCode7 = "[FFL007]"
    private static let fullFontLogCode8 = "[FFL008]"
    private static let fullFontLogCode9 = "[FFL009]"

    static let keyTimestamp = "timestamp"
    static let keyName = "name"
    static let fontExtension = ".ttf"
    static let sevenDays: Double = 7 * 24 * 60 * 60

    private static let queue = DispatchQueue(label: "com.rokt.fontmanager", attributes: .concurrent)
    private static var fontsToDownload: [FontModel] = []
    private static var existingPostScriptNames: [String] = []

    static func getExistingFontsByPostScriptName() {
        queue.sync(flags: .barrier) {
            existingPostScriptNames.removeAll()
            let familyNames = UIFont.familyNames.filter({ $0.lowercased() != "system font" })

            for familyName in familyNames {
                existingPostScriptNames.append(familyName)
                let fontNames = UIFont.fontNames(forFamilyName: familyName)
                existingPostScriptNames.append(contentsOf: fontNames)
            }
        }
    }

    static func reRegisterFonts(completionHandler: (() -> Void)? = nil) {
        let fontsSnapshot = queue.sync { fontsToDownload }

        guard !fontsSnapshot.isEmpty else {
            completionHandler?()
            return
        }

        for fontModel in fontsSnapshot {
            let registeredFontName = fontModel.postScriptName ?? fontModel.name

            guard let fileUrl = getFileUrl(name: registeredFontName) else {
                RoktAPIHelper.sendDiagnostics(message: fontDiagnosticCode,
                                              callStack: "font: \(fontModel.url), error: FileManager default urls")
                RoktLogger.shared.error("Error in font fileManager url for: \(fontModel.url)")
                continue
            }

            registerFont(font: fontModel, fileUrl: fileUrl)
        }

        completionHandler?()
    }

    class func downloadFonts(_ fonts: [FontModel], _ onFontDownloadComplete: @escaping @Sendable () -> Void) {
        getExistingFontsByPostScriptName()

        guard !fonts.isEmpty else {
            onFontDownloadComplete()
            return
        }

        NotificationCenter.default.post(Notification(name: Notification.Name(downloadingFonts)))

        // Each font settles exactly once, whether it was downloaded, loaded from cache,
        // skipped as a system font, or failed outright. Completion is driven by that
        // count so it can never depend on a font's position in `fonts`.
        let batch = FontDownloadBatch(expected: fonts.count)
        let settle = {
            finish(batch) {
                getExistingFontsByPostScriptName()
                NotificationCenter.default.post(Notification(name: Notification.Name(finishedDownloadingFonts)))
                onFontDownloadComplete()
            }
        }

        for font in fonts {
            let registeredFontName = font.postScriptName ?? font.name

            guard !isSystemFont(font: font) else {
                // Log FFL001
                sendFullFontLogs("Font retrieved from system \(registeredFontName)", fontLogId: fullFontLogCode1)
                settle()
                continue
            }

            // additional check if font can be created in local caches directory
            guard let fileUrl = getFileUrl(name: registeredFontName) else {
                // Best-effort: mark for diagnostics, don't un-initialise.
                Rokt.shared.roktImplementation.isInitFailedForFont = true
                RoktAPIHelper.sendDiagnostics(message: fontDiagnosticCode,
                                              callStack: "font: \(font.url), error: FileManager default urls")
                RoktLogger.shared.error("Error in font fileManager url for: \(font.url)")
                settle()
                continue
            }

            if FontManager.isDownloadingFontRequired(font: font) {
                RoktNetWorkAPI.downloadFont(font: font, destinationURL: fileUrl) {
                    settle()
                }
            } else {
                registerFont(font: font, fileUrl: fileUrl)
                settle()
            }
        }
    }

    /// Settles one font against `batch` and, for whichever call completes it, runs
    /// `complete` on the main queue. Download callbacks already land there, so keeping the
    /// batch completion on main leaves `finishedDownloadingFonts` observers where they were
    /// and keeps the barrier in `getExistingFontsByPostScriptName` off the cooperative pool.
    private static func finish(_ batch: FontDownloadBatch, then complete: @escaping @Sendable () -> Void) {
        Task {
            guard await batch.settle() else { return }

            DispatchQueue.main.async(execute: complete)
        }
    }

    class func registerFont(font: FontModel, fileUrl: URL, isDownloaded: Bool = false) {
        if let fontData = try? NSData(contentsOf: fileUrl, options: [.mappedIfSafe]),
           let dataProvider = CGDataProvider(data: fontData) {
            if let cgFont = CGFont(dataProvider) {
                let logLoadType = isDownloaded ? logFontDownloadedType : logFontPreloadedType
                if Rokt.shared.roktImplementation.initFeatureFlags.isEnabled(.shouldUseFontRegisterWithUrl) {
                    registerURLFont(fileUrl: fileUrl, cgFont: cgFont,
                                    fontUrlString: font.url,
                                    logLoadType: logLoadType)
                } else {
                    registerGraphicFont(cgFont: cgFont,
                                        fontUrlString: font.url,
                                        logLoadType: logLoadType)
                }

                if isDownloaded {
                    saveFontDetails(font: font)
                }

                recoveryLedger.clear(font.url)
            } else {
                handleRegistrationFailure(font: font,
                                          isDownloaded: isDownloaded,
                                          reason: "registering font on device",
                                          logMessage: "Error registering font on device: \(font.url)")
            }
        } else {
            handleRegistrationFailure(font: font,
                                      isDownloaded: isDownloaded,
                                      reason: "reading font data",
                                      logMessage: "Error reading font data: \(font.url)")
        }
    }

    private static func handleRegistrationFailure(font: FontModel,
                                                  isDownloaded: Bool,
                                                  reason: String,
                                                  logMessage: String) {
        // Best-effort: mark for diagnostics, don't un-initialise.
        Rokt.shared.roktImplementation.isInitFailedForFont = true
        RoktLogger.shared.error(logMessage)
        RoktAPIHelper.sendDiagnostics(message: fontDiagnosticCode,
                                      callStack: "font: \(font.url), error: \(reason)")

        // A file that has just been fetched and still will not register points at the
        // asset rather than the cache, so re-fetching it would fail the same way. Drop
        // it anyway so a poisoned file is not left behind for the next launch to read.
        guard !isDownloaded else {
            invalidateCachedFont(font)
            return
        }

        recoverCachedFont(font, reason: reason)
    }

    internal static func registerGraphicFont(cgFont: CGFont, fontUrlString: String, logLoadType: String) {
        var errorFont: Unmanaged<CFError>?
        if CTFontManagerRegisterGraphicsFont(cgFont, &errorFont) {
            // Log FFL005
            sendFullFontLogs("Font Graphic \(logLoadType) and registered \(cgFont.postScriptName ?? "" as CFString)",
                             fontLogId: fullFontLogCode5)
        } else {
            let errorLog = String(format: registerGraphicsFontErrorMsg, fontUrlString,
                                  String(describing: errorFont?.takeUnretainedValue()))
            sendRegisterDiagnostics(error: errorFont, log: errorLog)
            RoktLogger.shared.warning(errorLog)
        }
    }

    internal static func registerURLFont(fileUrl: URL, cgFont: CGFont, fontUrlString: String, logLoadType: String) {
        var errorFont: Unmanaged<CFError>?
        if CTFontManagerRegisterFontsForURL(fileUrl as CFURL, .process, &errorFont) {
            // Log FFL006
            sendFullFontLogs("Font URL \(logLoadType) and registered \(cgFont.postScriptName ?? "" as CFString)",
                             fontLogId: fullFontLogCode6)
        } else {
            let errorLog = String(format: registerUrlFontErrorMsg, fontUrlString,
                                  String(describing: errorFont?.takeUnretainedValue()))
            sendRegisterDiagnostics(error: errorFont, log: errorLog)
            RoktLogger.shared.warning(errorLog)
        }
    }

    static func isDownloadingFontRequired(font: FontModel) -> Bool {
        let registeredFontName = font.postScriptName ?? font.name

        guard let storedFonts = FontRepository.loadFontDetail(key: font.url),
              let fontTimeStampString = storedFonts[keyTimestamp],
              let fontTimeStamp = Double(fontTimeStampString),
              isFontFileExist(name: registeredFontName)
        else { return true }

        if Rokt.shared.roktImplementation.initFeatureFlags.isEnabled(.temporaryFontCache) {
            return isFontExpired(timeStamp: fontTimeStamp)
        }

        return false
    }

    static func isSystemFont(font: FontModel) -> Bool {
        let registeredFontName = font.postScriptName ?? font.name

        return queue.sync {
            existingPostScriptNames.contains { $0 == registeredFontName }
        }
    }

    static func saveFontDetails(font: FontModel) {
        FontRepository.saveFontUrl(key: font.url)

        let registeredFontName = font.postScriptName ?? font.name
        let fontDetail = [keyName: registeredFontName, keyTimestamp: "\(Date().timeIntervalSince1970)"]
        FontRepository.saveFontDetail(key: font.url, values: fontDetail)
    }

    static func isFontExpired(timeStamp: Double) -> Bool {
        return Date().timeIntervalSince1970 - timeStamp > sevenDays
    }

    static func removeUnusedFonts(fonts: [FontModel]) {
        guard var downloadedFonts = FontRepository.loadAllFontURLs() else { return }

        for font in fonts {
            guard let indexOfDownloadedFont = downloadedFonts.firstIndex(of: font.url) else { continue }

            downloadedFonts.remove(at: indexOfDownloadedFont)
        }

        for downloadedFont in downloadedFonts {
            removeFont(key: downloadedFont)
        }
    }

    private static func removeFont(key: String) {
        guard let storedFontDetails = FontRepository.loadFontDetail(key: key) else { return }

        FontRepository.removeFontUrl(key: key)
        FontRepository.removeFontDetail(key: key)

        guard let fontName = storedFontDetails[keyName],
              let fileUrl = getFileUrl(name: fontName),
              FileManager.default.fileExists(atPath: fileUrl.path)
        else { return }

        do {
            try FileManager.default.removeItem(at: fileUrl)
            // Log FFL007
            sendFullFontLogs("Font removed \(fontName)", fontLogId: fullFontLogCode7)
        } catch {
            RoktAPIHelper.sendDiagnostics(
                message: fontDiagnosticCode,
                callStack: "Failed to remove file \(fontName)"
            )
        }
    }

    // MARK: - Cache recovery

    /// Fonts live in `Library/Caches`, which the OS may purge at any time, and a purge
    /// can leave a partially written file behind. Because `isDownloadingFontRequired`
    /// treats any present file as usable, an unreadable one would otherwise be re-read
    /// and re-rejected on every render, pinning the layout to the fallback font for the
    /// life of the install. Dropping the cache entry lets the next pass re-fetch it.
    ///
    /// Attempts are capped per font per process so a permanently bad asset cannot loop,
    /// and the re-fetch is always asynchronous so it never delays a render.
    static var maxFontRecoveryAttempts = 2
    static var fontRecoveryBackoff: DispatchTimeInterval = .seconds(1)

    private static let recoveryLedger = FontRecoveryLedger()

    static func resetFontRecoveryState() {
        recoveryLedger.reset()
    }

    private static func recoverCachedFont(_ font: FontModel, reason: String) {
        let attempt = recoveryLedger.recordAttempt(for: font.url)

        guard attempt <= maxFontRecoveryAttempts else {
            RoktAPIHelper.sendDiagnostics(
                message: fontDiagnosticCode,
                callStack: "font: \(font.url), error: font recovery exhausted after " +
                    "\(maxFontRecoveryAttempts) attempt(s), \(reason)"
            )
            return
        }

        invalidateCachedFont(font)

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + fontRecoveryBackoff) {
            guard let fileUrl = getFileUrl(name: font.postScriptName ?? font.name) else { return }
            RoktNetWorkAPI.downloadFont(font: font, destinationURL: fileUrl) {}
        }
    }

    /// Removes the cached file and both metadata records so `isDownloadingFontRequired`
    /// reports the font as missing on the next pass.
    ///
    /// Dropping the detail alone would be enough to trigger a re-download, but it would
    /// strand the URL entry: `removeFont` reads the detail first and returns early when it
    /// is absent, so `removeUnusedFonts` could never clean the entry up afterwards. A
    /// successful re-download re-adds both records.
    internal static func invalidateCachedFont(_ font: FontModel, completion: (() -> Void)? = nil) {
        if let fileUrl = getFileUrl(name: font.postScriptName ?? font.name),
           FileManager.default.fileExists(atPath: fileUrl.path) {
            try? FileManager.default.removeItem(at: fileUrl)
        }

        FontRepository.removeFontDetail(key: font.url) {
            FontRepository.removeFontUrl(key: font.url) { completion?() }
        }
    }

    #if DEBUG
    /// `FileManager` always reports a caches directory on a real device, so the
    /// unresolvable-path branch can only be exercised through this seam. Compiled out of
    /// release builds so it never ships.
    internal static var fileUrlResolverOverride: ((String) -> URL?)?
    #endif

    internal static func getFileUrl(name: String) -> URL? {
        #if DEBUG
        if let fileUrlResolverOverride {
            return fileUrlResolverOverride(name)
        }
        #endif

        guard let cacheDirectoryUrl = FontRepository.getCacheDirectoryUrl() else {
            // Log FFL009
            sendFullFontLogs("File Manager failed to read caches directory in user home", fontLogId: fullFontLogCode9)
            return nil
        }

        let fullPath = cacheDirectoryUrl.appendingPathComponent("\(name)\(fontExtension)")
        // Log FFL008
        sendFullFontLogs("Full file path URL: \(fullPath)", fontLogId: fullFontLogCode8)
        return fullPath
    }

    internal static func isFontFileExist(name: String) -> Bool {
        guard let fileURL = getFileUrl(name: name) else { return false }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    internal static func sendRegisterDiagnostics(error: Unmanaged<CFError>?, log: String) {
        let suppressedFontErrorCodes = [
            CTFontManagerError.alreadyRegistered.rawValue, // Code=105
            CTFontManagerError.duplicatedName.rawValue // Code=305
        ]

        let errorObject = error?.takeUnretainedValue()
        if errorObject == nil || !suppressedFontErrorCodes.contains(CFErrorGetCode(errorObject)) {
            // Send diagnostic only if CFError nil or code is not in suppressedFontErrorCodes
            RoktAPIHelper.sendDiagnostics(message: fontDiagnosticCode, callStack: log)
            return
        }
    }

    internal static func sendFullFontLogs(_ msg: String, fontLogId: String) {
        guard Rokt.shared.roktImplementation.initFeatureFlags.isEnabled(.shouldLogFontHappyPath) else { return }
        RoktLogger.shared.debug(msg)
        RoktAPIHelper.sendDiagnostics(message: fullFontLogDiagnosticCode,
                                      callStack: "\(fontLogId) \(msg)",
                                      severity: .info)
    }
}

/// Per-font recovery budget for the life of the process.
///
/// Deliberately synchronous, and so lock-guarded rather than actor-isolated: the budget is
/// read and written from `registerFont`, which `reRegisterFonts` calls on the render path.
/// Isolating it would make that path `async` and defer the execute continuation that drives
/// the cache lookup and presentation. The lock is owned here so no call site handles one.
private final class FontRecoveryLedger {
    private let lock = NSLock()
    private var attempts: [String: Int] = [:]

    func reset() {
        withLock { $0.removeAll() }
    }

    func clear(_ fontUrl: String) {
        withLock { $0[fontUrl] = nil }
    }

    /// Records an attempt for `fontUrl` and returns its 1-based number.
    func recordAttempt(for fontUrl: String) -> Int {
        withLock {
            let attempt = ($0[fontUrl] ?? 0) + 1
            $0[fontUrl] = attempt
            return attempt
        }
    }

    private func withLock<T>(_ body: (inout [String: Int]) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(&attempts)
    }
}

/// Counts fonts as they settle. Fonts settle out of order and from whichever thread their
/// download callback lands on, so a positional check cannot be used and the count needs
/// serialising; actor isolation lets the compiler enforce that rather than a hand-held lock.
private actor FontDownloadBatch {
    private let expected: Int
    private var settled = 0
    private var hasCompleted = false

    init(expected: Int) {
        self.expected = expected
    }

    /// Records one settled font. Returns `true` for the single call that settles the last
    /// outstanding font and `false` for every other call, so completion work runs off the
    /// actor and cannot be triggered twice.
    func settle() -> Bool {
        settled += 1

        guard !hasCompleted, settled >= expected else { return false }

        hasCompleted = true
        return true
    }
}
