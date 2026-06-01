import Foundation

class FontDiagnosticsViewModel {
    public init(processedFontDiagnostics: Set<FontDiagnostics> = Set<FontDiagnostics>()) {
        self.processedFontDiagnostics = processedFontDiagnostics
    }

    public var processedFontDiagnostics = Set<FontDiagnostics>()

    public func insertProcessedFontDiagnostics(_ fontFamily: String) -> Bool {
        let pendingFontDiagnostics = FontDiagnostics(fontFamily: fontFamily)
        return processedFontDiagnostics.insert(pendingFontDiagnostics).inserted
    }
}
