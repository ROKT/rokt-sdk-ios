import Foundation

// Event `data` values are either flat strings or nested string maps (capture-attributes partner snapshot).
internal enum TxnEventDataValue: Codable, Equatable, ExpressibleByStringLiteral {
    case string(String)
    case object([String: String])

    init(stringLiteral value: String) {
        self = .string(value)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: String].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "TxnEventDataValue is neither a String nor a [String: String]"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

// Only the rotated session_token is consumed client-side; absent token leaves the current one in place.
internal struct TxnEventsResponse: Decodable, Equatable {
    let sessionToken: TxnSessionToken?

    enum CodingKeys: String, CodingKey {
        case sessionToken = "session_token"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionToken = try container.decodeIfPresent(TxnSessionToken.self, forKey: .sessionToken)
    }
}
