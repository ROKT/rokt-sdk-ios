// periphery:ignore:all - net-new v2 init response models, not yet wired into the live path
import Foundation

internal struct InitResponse: Decodable, Equatable {
    let sessionId: String
    let sessionToken: SessionToken
    let featureFlags: FeatureFlags
    let fonts: [FontItem]

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case sessionToken = "session_token"
        case featureFlags = "feature_flags"
        case fonts
    }

    init(
        sessionId: String,
        sessionToken: SessionToken,
        featureFlags: FeatureFlags,
        fonts: [FontItem]
    ) {
        self.sessionId = sessionId
        self.sessionToken = sessionToken
        self.featureFlags = featureFlags
        self.fonts = fonts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        sessionToken = try container.decode(SessionToken.self, forKey: .sessionToken)
        // Tolerate absent feature_flags/fonts so a missing block doesn't fail init.
        featureFlags = try container.decodeIfPresent(FeatureFlags.self, forKey: .featureFlags)
            ?? FeatureFlags(flags: [:])
        fonts = try container.decodeIfPresent([FontItem].self, forKey: .fonts) ?? []
    }
}

internal struct SessionToken: Decodable, Equatable {
    let token: String
    let expiresAt: Int64 // Unix epoch milliseconds

    enum CodingKeys: String, CodingKey {
        case token
        case expiresAt = "expires_at"
    }

    var expiresAtDate: Date {
        Date(timeIntervalSince1970: TimeInterval(expiresAt)/1000)
    }
}

internal struct FontItem: Decodable, Equatable {
    let fontName: String
    let fontURL: String
    let fontStyle: String?
    let fontWeight: String?
    let fontPostScriptName: String?

    enum CodingKeys: String, CodingKey {
        case fontName = "font_name"
        case fontURL = "font_url"
        case fontStyle = "font_style"
        case fontWeight = "font_weight"
        case fontPostScriptName = "font_post_script_name"
    }
}

internal enum FeatureFlagValue: Decodable, Equatable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Bool before the numeric kinds so JSON booleans aren't coerced into numbers.
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported feature flag value type"
            )
        }
    }
}

internal struct FeatureFlags: Decodable, Equatable {
    let flags: [String: FeatureFlagValue]

    init(flags: [String: FeatureFlagValue]) {
        self.flags = flags
    }

    init(from decoder: Decoder) throws {
        // Decode per-key and skip values whose type isn't modeled, so a single
        // unknown/extensible server flag can't fail the whole init response.
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var decoded: [String: FeatureFlagValue] = [:]
        for key in container.allKeys {
            if let value = try? container.decode(FeatureFlagValue.self, forKey: key) {
                decoded[key.stringValue] = value
            }
        }
        flags = decoded
    }

    private struct DynamicCodingKey: CodingKey {
        let stringValue: String
        let intValue: Int? = nil

        init(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            return nil
        }
    }

    func bool(forKey key: String) -> Bool? {
        if case .bool(let value) = flags[key] { return value }
        return nil
    }

    func int(forKey key: String) -> Int? {
        if case .int(let value) = flags[key] { return value }
        return nil
    }

    func string(forKey key: String) -> String? {
        if case .string(let value) = flags[key] { return value }
        return nil
    }
}

extension FeatureFlags {
    // minimum-post-purchase-schema is server-gated: a non-empty version string means
    // the schema requirement is met, so string flags map to match = !isEmpty.
    func toInitFeatureFlags() -> InitFeatureFlags {
        var items: [String: FeatureFlagItem] = [:]
        for (key, value) in flags {
            switch value {
            case .bool(let flag):
                items[key] = FeatureFlagItem(match: flag)
            case .string(let version):
                items[key] = FeatureFlagItem(match: !version.isEmpty)
            case .int, .double:
                continue
            }
        }

        return InitFeatureFlags(
            roktTrackingStatus: bool(forKey: "rokt-tracking-status") ?? true,
            featureFlags: items
        )
    }
}
