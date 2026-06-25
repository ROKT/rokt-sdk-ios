// periphery:ignore:all - net-new v2 offers network models, not yet wired into the live path
import Foundation

// MARK: - Request

/// Request body for `POST /v2/sessions/offers` on the Transactions API.
///
/// The session is identified solely by the JWT `sub` claim in the
/// `Authorization` header — there is intentionally no `session_id` in the body.
/// Platform/channel context travels in ``channel``; the legacy v1 experiences
/// call carried these as implicit headers.
///
/// Mirrors Android #1039's `SelectRequest`. `customer` and `page.url` are
/// accepted by the provider but intentionally omitted here to match Android.
internal struct TxnSelectRequest: Encodable, Equatable {
    let page: TxnSelectPage
    let channel: TxnSelectChannel
    let attributes: [String: String]
    let privacyControl: TxnSelectPrivacyControl?

    enum CodingKeys: String, CodingKey {
        case page
        case channel
        case attributes
        case privacyControl = "privacy_control"
    }

    init(
        page: TxnSelectPage,
        channel: TxnSelectChannel,
        attributes: [String: String] = [:],
        privacyControl: TxnSelectPrivacyControl? = nil
    ) {
        self.page = page
        self.channel = channel
        self.attributes = attributes
        self.privacyControl = privacyControl
    }
}

internal struct TxnSelectPage: Encodable, Equatable {
    let pageIdentifier: String

    enum CodingKeys: String, CodingKey {
        case pageIdentifier = "page_identifier"
    }
}

/// Channel descriptor. ``type`` is always encoded (`"msdk"`) so the backend
/// derives the channel source — there are no longer any `rokt-platform-type` /
/// `rokt-integration-type` headers carrying it.
internal struct TxnSelectChannel: Encodable, Equatable {
    static let channelTypeMsdk = "msdk"

    let type: String
    let sdkVersion: String

    enum CodingKeys: String, CodingKey {
        case type
        case sdkVersion = "sdk_version"
    }

    init(type: String = TxnSelectChannel.channelTypeMsdk, sdkVersion: String) {
        self.type = type
        self.sdkVersion = sdkVersion
    }
}

/// SDK-side privacy consent signals for offer selection. Mirrors Android's
/// `privacy_control` block (NOT the legacy `privacy`/`do_not_track` shape).
internal struct TxnSelectPrivacyControl: Encodable, Equatable {
    let noFunctional: Bool?
    let noTargeting: Bool?
    let doNotShareOrSell: Bool?

    enum CodingKeys: String, CodingKey {
        case noFunctional = "no_functional"
        case noTargeting = "no_targeting"
        case doNotShareOrSell = "do_not_share_or_sell"
    }

    init(noFunctional: Bool? = nil, noTargeting: Bool? = nil, doNotShareOrSell: Bool? = nil) {
        self.noFunctional = noFunctional
        self.noTargeting = noTargeting
        self.doNotShareOrSell = doNotShareOrSell
    }
}

// MARK: - Response

/// Response body for `POST /v2/sessions/offers` on the Transactions API.
///
/// Mirrors Android #1039's `SelectResponse`. Fields are optional / defaulted
/// because the provider emits `omitempty` throughout; mapping into the render
/// models the UX layer consumes is a later PR. `JSONDecoder` ignores unknown
/// keys by default, so additional provider fields don't fail the decode.
///
/// The DCUI schemas (``TxnSelectPluginConfig/outerLayoutSchema``,
/// ``TxnSelectLayoutVariant/layoutVariantSchema``) arrive as pre-serialized JSON
/// strings — the shape the render layer expects — so they are kept as `String`
/// with no re-encoding.
internal struct TxnSelectResponse: Decodable, Equatable {
    let sessionId: String
    let sessionToken: TxnSessionToken
    let pageInstanceGuid: String
    let pageContext: TxnSelectPageContext?
    let plugins: [TxnSelectPlugin]?
    let eventData: [String: TxnSelectEventDataEntry]?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case sessionToken = "session_token"
        case pageInstanceGuid = "page_instance_guid"
        case pageContext = "page_context"
        case plugins
        case eventData = "event_data"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        sessionToken = try container.decode(TxnSessionToken.self, forKey: .sessionToken)
        pageInstanceGuid = try container.decodeIfPresent(String.self, forKey: .pageInstanceGuid) ?? ""
        pageContext = try container.decodeIfPresent(TxnSelectPageContext.self, forKey: .pageContext)
        plugins = try container.decodeIfPresent([TxnSelectPlugin].self, forKey: .plugins)
        eventData = try container.decodeIfPresent([String: TxnSelectEventDataEntry].self, forKey: .eventData)
    }
}

internal struct TxnSelectPageContext: Decodable, Equatable {
    let pageInstanceGuid: String?
    let pageId: String?
    let language: String?
    let token: String?

    enum CodingKeys: String, CodingKey {
        case pageInstanceGuid = "page_instance_guid"
        case pageId = "page_id"
        case language
        case token
    }
}

internal struct TxnSelectPlugin: Decodable, Equatable {
    let plugin: TxnSelectPluginLayout?
}

internal struct TxnSelectPluginLayout: Decodable, Equatable {
    let id: String?
    let name: String?
    let targetElementSelector: String?
    let config: TxnSelectPluginConfig?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case targetElementSelector = "target_element_selector"
        case config
    }
}

internal struct TxnSelectPluginConfig: Decodable, Equatable {
    let slots: [TxnSelectSlot]
    let instanceGuid: String?
    let outerLayoutSchema: String?
    let token: String?

    enum CodingKeys: String, CodingKey {
        case slots
        case instanceGuid = "instance_guid"
        case outerLayoutSchema = "outer_layout_schema"
        case token
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        slots = try container.decodeIfPresent([TxnSelectSlot].self, forKey: .slots) ?? []
        instanceGuid = try container.decodeIfPresent(String.self, forKey: .instanceGuid)
        outerLayoutSchema = try container.decodeIfPresent(String.self, forKey: .outerLayoutSchema)
        token = try container.decodeIfPresent(String.self, forKey: .token)
    }
}

internal struct TxnSelectSlot: Decodable, Equatable {
    let instanceGuid: String?
    let layoutVariant: TxnSelectLayoutVariant?
    let offer: TxnSelectOffer?
    let token: String?

    enum CodingKeys: String, CodingKey {
        case instanceGuid = "instance_guid"
        case layoutVariant = "layout_variant"
        case offer
        case token
    }
}

internal struct TxnSelectLayoutVariant: Decodable, Equatable {
    let layoutVariantId: String?
    let moduleName: String?
    let layoutVariantSchema: String?

    enum CodingKeys: String, CodingKey {
        case layoutVariantId = "layout_variant_id"
        case moduleName = "module_name"
        case layoutVariantSchema = "layout_variant_schema"
    }
}

internal struct TxnSelectOffer: Decodable, Equatable {
    let campaignId: String?
    let creative: TxnSelectCreative?
    // Catalog items (shoppable ads) are kept on the wire model but deferred in
    // the mapper; surfacing them is a follow-up PR.
    let catalogItems: [TxnJSONValue]?

    enum CodingKeys: String, CodingKey {
        case campaignId = "campaign_id"
        case creative
        case catalogItems = "catalog_items"
    }
}

internal struct TxnSelectCreative: Decodable, Equatable {
    let referralCreativeId: String?
    let instanceGuid: String?
    let token: String?
    let responseOptionsMap: [String: TxnSelectResponseOption]?
    let copy: [String: String]?
    let images: [String: TxnSelectImage]?
    let links: [String: TxnSelectLink]?
    let icons: [String: TxnSelectIcon]?

    enum CodingKeys: String, CodingKey {
        case referralCreativeId = "referral_creative_id"
        case instanceGuid = "instance_guid"
        case token
        case responseOptionsMap = "response_options_map"
        case copy
        case images
        case links
        case icons
    }
}

internal struct TxnSelectResponseOption: Decodable, Equatable {
    let id: String?
    let action: String?
    let instanceGuid: String?
    let token: String?
    let signalType: String?
    let shortLabel: String?
    let longLabel: String?
    let shortSuccessLabel: String?
    let isPositive: Bool
    let url: String?
    let ignoreBranch: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case action
        case instanceGuid = "instance_guid"
        case token
        case signalType = "signal_type"
        case shortLabel = "short_label"
        case longLabel = "long_label"
        case shortSuccessLabel = "short_success_label"
        case isPositive = "is_positive"
        case url
        case ignoreBranch = "ignore_branch"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        action = try container.decodeIfPresent(String.self, forKey: .action)
        instanceGuid = try container.decodeIfPresent(String.self, forKey: .instanceGuid)
        token = try container.decodeIfPresent(String.self, forKey: .token)
        signalType = try container.decodeIfPresent(String.self, forKey: .signalType)
        shortLabel = try container.decodeIfPresent(String.self, forKey: .shortLabel)
        longLabel = try container.decodeIfPresent(String.self, forKey: .longLabel)
        shortSuccessLabel = try container.decodeIfPresent(String.self, forKey: .shortSuccessLabel)
        isPositive = try container.decodeIfPresent(Bool.self, forKey: .isPositive) ?? false
        url = try container.decodeIfPresent(String.self, forKey: .url)
        ignoreBranch = try container.decodeIfPresent(Bool.self, forKey: .ignoreBranch)
    }
}

internal struct TxnSelectImage: Decodable, Equatable {
    let light: String?
    let dark: String?
    let alt: String?
    let title: String?
}

internal struct TxnSelectLink: Decodable, Equatable {
    let url: String?
    let title: String?
}

internal struct TxnSelectIcon: Decodable, Equatable {
    let name: String?
}

/// Token lookup for a trackable entity, echoed back on `/v2/sessions/events`.
internal struct TxnSelectEventDataEntry: Decodable, Equatable {
    let token: String
    let events: [String: TxnSelectRealTimeEvent]?
}

/// A pre-serialized real-time event payload, keyed by signal type. Mirrors the
/// provider's typed event shape (and Android's `SelectRealTimeEvent`).
internal struct TxnSelectRealTimeEvent: Decodable, Equatable {
    let eventType: String?
    let payload: String?

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case payload
    }
}

/// Opaque JSON value for `catalog_items`, kept un-shaped on purpose: surfacing
/// shoppable ads is deferred to the mapper in a follow-up. Decoded so the
/// payload round-trips and is retained on the wire model, but not interpreted here.
internal enum TxnJSONValue: Decodable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([TxnJSONValue])
    case object([String: TxnJSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([TxnJSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: TxnJSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value"
            )
        }
    }
}
