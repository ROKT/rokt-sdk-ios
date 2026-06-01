import Foundation

extension CreativeImage {
    /// Alt text to expose to VoiceOver, or `nil` when `alt` is empty or a non-descriptive backend default.
    var accessibilityAltText: String? {
        guard let trimmed = alt?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              !kNonDescriptiveCreativeImageAltTexts.contains(trimmed.lowercased()) else {
            return nil
        }
        return trimmed
    }
}
