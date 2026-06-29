// periphery:ignore:all - offers render adapter
import Foundation

/// Adapts the offers ``SelectResponse`` into the experience JSON string the
/// renderer decodes (`RoktUXExperienceResponse`) via ``RenderExperience``. The
/// pre-serialized DCUI layout-schema strings pass through verbatim; the
/// offer/creative subtree is re-homed to the renderer's camelCase contract.
internal enum SelectExperienceAdapter {

    enum AdapterError: Error {
        case encodingFailed
    }

    static func experienceJSONString(from response: SelectResponse) throws -> String {
        let encoder = JSONEncoder()
        // Deterministic key order so the rendered experience string is stable
        // (the render layer parses by key; the embedded DCUI schemas are untouched).
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(RenderExperience(response))
        guard let string = String(data: data, encoding: .utf8) else {
            throw AdapterError.encodingFailed
        }
        return string
    }
}
