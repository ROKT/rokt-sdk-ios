import Foundation
import UIKit
internal class FontManager {
    static let keyTimestamp = "timestamp"
    static let keyName = "name"
    static let fontExtension = ".ttf"
    static let sevenDays: Double = 7 * 24 * 60 * 60

    private static var fontsToDownload: [FontModel] = []
    private static var existingPostScriptNames: [String] = []

    static func getExistingFontsByPostScriptName() {
        existingPostScriptNames.removeAll()
        let familyNames = UIFont.familyNames.filter({ $0.lowercased() != "system font" })

        for familyName in familyNames {
            existingPostScriptNames.append(familyName)
            let fontNames = UIFont.fontNames(forFamilyName: familyName)
            existingPostScriptNames.append(contentsOf: fontNames)
        }
    }

    static func reRegisterFonts(completionHandler: (() -> Void)? = nil) {
        guard !fontsToDownload.isEmpty else {
            completionHandler?()
            return
        }

        for fontModel in fontsToDownload {
            let registeredFontName = fontModel.postScriptName ?? fontModel.name

            guard let fileUrl = getFileUrl(name: registeredFontName) else {
                RoktAPIHelper.sendDiagnostics(message: kAPIFontErrorCode,
                                              callStack: "font: \(fontModel.url), error: FileManager default urls")
                RoktLogger.shared.error("Error in font fileManager url for: \(fontModel.url)")
                continue
            }

            registerFont(font: fontModel, fileUrl: fileUrl)
        }

        completionHandler?()
    }

    class func downloadFonts(_ fonts: [FontModel], _ onFontDownloadComplete: @escaping () -> Void) {
        getExistingFontsByPostScriptName()
        var fontDownloadInProgress = false

        if !fonts.isEmpty {
            NotificationCenter.default.post(Notification(name: Notification.Name(kDownloadingFonts)))
            var downloadedFonts = 0

            for font in fonts {
                let registeredFontName = font.postScriptName ?? font.name

                guard !isSystemFont(font: font) else {
                    // Log FFL001
                    sendFullFontLogs("Font retrieved from system \(registeredFontName)", fontLogId: kFullFontLogCode1)
                    downloadedFonts += 1

                    if downloadedFonts == fonts.count {
                        NotificationCenter.default.post(Notification(name:
                                                                        Notification.Name(kFinishedDownloadingFonts)))
                    }

                    continue
                }

                // additional check if font can be created in local documents directory
                guard let fileUrl = getFileUrl(name: registeredFontName) else {
                    Rokt.shared.roktImplementation.isInitialized = false
                    Rokt.shared.roktImplementation.isInitFailedForFont = true
                    RoktAPIHelper.sendDiagnostics(message: kAPIFontErrorCode,
                                                  callStack: "font: \(font.url), error: FileManager default urls")
                    RoktLogger.shared.error("Error in font fileManager url for: \(font.url)")
                    NotificationCenter.default.post(Notification(name:
                                                                    Notification.Name(kFinishedDownloadingFonts)))
                    return
                }

                if isSystemFont(font: font) {
                    // Log FFL002
                    sendFullFontLogs("Font retrieved from system \(registeredFontName)", fontLogId: kFullFontLogCode2)
                    downloadedFonts += 1
                    if downloadedFonts == fonts.count {
                        NotificationCenter.default.post(Notification(name:
                                                                        Notification.Name(kFinishedDownloadingFonts)))
                    }
                } else if FontManager.isDownloadingFontRequired(font: font) {
                    downloadedFonts += 1

                    fontDownloadInProgress = true
                    RoktNetWorkAPI.downloadFont(
                        font: font,
                        destinationURL: fileUrl,
                        isLastFont: downloadedFonts == fonts.count
                    ) { isLastFont in
                        if isLastFont {
                            onFontDownloadComplete()
                        }
                    }
                } else {
                    registerFont(font: font, fileUrl: fileUrl)
                    downloadedFonts += 1
                    if downloadedFonts == fonts.count {
                        NotificationCenter.default.post(Notification(name:
                                                                        Notification.Name(kFinishedDownloadingFonts)))
                    }
                }
            }
        }

        if !fontDownloadInProgress {
            onFontDownloadComplete()
        }
        getExistingFontsByPostScriptName()
    }

    class func registerFont(font: FontModel, fileUrl: URL, isDownloaded: Bool = false) {
        if let fontData = try? NSData(contentsOf: fileUrl, options: [.mappedIfSafe]),
           let dataProvider = CGDataProvider(data: fontData) {
            if let cgFont = CGFont(dataProvider) {
                let logLoadType = isDownloaded ? kLogFontDownloadedType : kLogFontPreloadedType
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
            } else {
                Rokt.shared.roktImplementation.isInitialized = false
                Rokt.shared.roktImplementation.isInitFailedForFont = true
                RoktLogger.shared.error("Error registering font on device: \(font.url)")
                RoktAPIHelper.sendDiagnostics(message: kAPIFontErrorCode,
                                              callStack: "font: \(font.url), error: registering font on device")
            }
        } else {
            Rokt.shared.roktImplementation.isInitialized = false
            Rokt.shared.roktImplementation.isInitFailedForFont = true
            RoktLogger.shared.error("Error reading font data: \(font.url)")
            RoktAPIHelper.sendDiagnostics(message: kAPIFontErrorCode,
                                          callStack: "font: \(font.url), error: reading font data")
        }
    }

    internal static func registerGraphicFont(cgFont: CGFont, fontUrlString: String, logLoadType: String) {
        var errorFont: Unmanaged<CFError>?
        if CTFontManagerRegisterGraphicsFont(cgFont, &errorFont) {
            // Log FFL005
            sendFullFontLogs("Font Graphic \(logLoadType) and registered \(cgFont.postScriptName ?? "" as CFString)",
                             fontLogId: kFullFontLogCode5)
        } else {
            let errorLog = String(format: kRegisterGraphicsFontErrorMsg, fontUrlString,
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
                             fontLogId: kFullFontLogCode6)
        } else {
            let errorLog = String(format: kRegisterURLFontErrorMsg, fontUrlString,
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

        return existingPostScriptNames.contains { $0 == registeredFontName }
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
            sendFullFontLogs("Font removed \(fontName)", fontLogId: kFullFontLogCode7)
        } catch {
            RoktAPIHelper.sendDiagnostics(
                message: kAPIFontErrorCode,
                callStack: "Failed to remove file \(fontName)"
            )
        }
    }

    internal static func getFileUrl(name: String) -> URL? {
        if let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fullPath = documentsUrl.appendingPathComponent("\(name)\(fontExtension)")
            // Log FFL008
            sendFullFontLogs("Full file path URL: \(fullPath)", fontLogId: kFullFontLogCode8)
            return fullPath
        }
        // Log FFL009
        sendFullFontLogs("File Manager failed to read documents directory in user home", fontLogId: kFullFontLogCode9)
        return nil
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
            RoktAPIHelper.sendDiagnostics(message: kAPIFontErrorCode, callStack: log)
            return
        }
    }

    internal static func sendFullFontLogs(_ msg: String, fontLogId: String) {
        guard Rokt.shared.roktImplementation.initFeatureFlags.isEnabled(.shouldLogFontHappyPath) else { return }
        RoktLogger.shared.debug(msg)
        RoktAPIHelper.sendDiagnostics(message: kAPIFullFontLogCode,
                                      callStack: "\(fontLogId) \(msg)",
                                      severity: .info)
    }
}
