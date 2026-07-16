// periphery:ignore:all
import Foundation

// MARK: - Request

/// Offers request body. Session identity is the JWT in the Authorization header.
internal struct SelectRequest: Encodable, Equatable {
    let page: SelectPage
    let channel: SelectChannel
    var attributes: [String: String] = [:]
    var privacyControl: SelectPrivacyControl?
    var privacy: SelectPrivacy?
    // Real-time events triggered during the previous placement, forwarded for the next
    // selection; omitted when none.
    var events: [SelectEvent]?

    enum CodingKeys: String, CodingKey {
        case page
        case channel
        case attributes
        case privacyControl = "privacy_control"
        case privacy
        case events
    }
}

internal struct SelectPage: Encodable, Equatable {
    let pageIdentifier: String

    enum CodingKeys: String, CodingKey {
        case pageIdentifier = "page_identifier"
    }
}

/// Channel descriptor. ``type`` (`"msdk"`) tells the backend the channel source
/// and ``platformType`` (`"iOS"`) the platform; both travel in the body. The
/// platform refines server-side page detection and targeting.
internal struct SelectChannel: Encodable, Equatable {
    static let channelTypeMsdk = "msdk"
    static let platformTypeIOS = "iOS"

    var type: String = SelectChannel.channelTypeMsdk
    let sdkVersion: String
    var platformType: String = SelectChannel.platformTypeIOS

    enum CodingKeys: String, CodingKey {
        case type
        case sdkVersion = "sdk_version"
        case platformType = "rokt_platform_type"
    }
}

/// SDK-side privacy consent signals for offer selection. Mirrors Android's
/// `privacy_control` block.
internal struct SelectPrivacyControl: Encodable, Equatable {
    let noFunctional: Bool?
    let noTargeting: Bool?
    let doNotShareOrSell: Bool?

    enum CodingKeys: String, CodingKey {
        case noFunctional = "no_functional"
        case noTargeting = "no_targeting"
        case doNotShareOrSell = "do_not_share_or_sell"
    }
}

/// GPC (Global Privacy Control) signal. A top-level sibling of
/// ``SelectPrivacyControl`` — `gpc_enabled` rides under `privacy`, not inside
/// `privacy_control`, matching Android.
internal struct SelectPrivacy: Encodable, Equatable {
    let gpcEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case gpcEnabled = "gpc_enabled"
    }
}

/// Real-time event forwarded on an offers request.
internal struct SelectEvent: Encodable, Equatable {
    let eventType: String
    let timestamp: Int64
    let payload: String

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case timestamp
        case data
    }

    private enum DataKeys: String, CodingKey {
        case payload
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventType, forKey: .eventType)
        try container.encode(timestamp, forKey: .timestamp)
        var data = container.nestedContainer(keyedBy: DataKeys.self, forKey: .data)
        try data.encode(payload, forKey: .payload)
    }
}

// MARK: - Response

/// Offers response body.
internal struct SelectResponse: Decodable, Equatable {
    let sessionId: String
    let sessionToken: TxnSessionToken
    let pageInstanceGuid: String
    let pageContext: SelectPageContext?
    let plugins: [SelectPlugin]?
    let eventData: [String: SelectEventDataEntry]?

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
        pageContext = try container.decodeIfPresent(SelectPageContext.self, forKey: .pageContext)
        plugins = try container.decodeIfPresent([SelectPlugin].self, forKey: .plugins)
        eventData = try container.decodeIfPresent([String: SelectEventDataEntry].self, forKey: .eventData)
    }
}

internal struct SelectPageContext: Decodable, Equatable {
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

internal struct SelectPlugin: Decodable, Equatable {
    let plugin: SelectPluginLayout?
}

internal struct SelectPluginLayout: Decodable, Equatable {
    let id: String?
    let name: String?
    let targetElementSelector: String?
    let config: SelectPluginConfig?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case targetElementSelector = "target_element_selector"
        case config
    }
}

internal struct SelectPluginConfig: Decodable, Equatable {
    let slots: [SelectSlot]
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
        slots = try container.decodeIfPresent([SelectSlot].self, forKey: .slots) ?? []
        instanceGuid = try container.decodeIfPresent(String.self, forKey: .instanceGuid)
        outerLayoutSchema = try container.decodeIfPresent(String.self, forKey: .outerLayoutSchema)
        token = try container.decodeIfPresent(String.self, forKey: .token)
    }
}

internal struct SelectSlot: Decodable, Equatable {
    let instanceGuid: String?
    let layoutVariant: SelectLayoutVariant?
    let offer: SelectOffer?
    let token: String?

    enum CodingKeys: String, CodingKey {
        case instanceGuid = "instance_guid"
        case layoutVariant = "layout_variant"
        case offer
        case token
    }
}

internal struct SelectLayoutVariant: Decodable, Equatable {
    let layoutVariantId: String?
    let moduleName: String?
    let layoutVariantSchema: String?

    enum CodingKeys: String, CodingKey {
        case layoutVariantId = "layout_variant_id"
        case moduleName = "module_name"
        case layoutVariantSchema = "layout_variant_schema"
    }
}

internal struct SelectOffer: Decodable, Equatable {
    let campaignId: String?
    let creative: SelectCreative?
    // Shoppable-ad catalog items, mapped to the renderer via `RenderCatalogItem`
    // (see RenderExperience) so instant-purchase layouts render their content.
    let catalogItems: [SelectCatalogItem]?

    enum CodingKeys: String, CodingKey {
        case campaignId = "campaign_id"
        case creative
        case catalogItems = "catalog_items"
    }
}

/// A shoppable catalog item on an offer. Only the fields the render model
/// consumes are declared; the lenient decoder skips anything else on the wire.
/// The `token` is echoed back on purchase events.
internal struct SelectCatalogItem: Decodable, Equatable {
    let catalogItemId: String?
    let instanceGuid: String?
    let cartItemId: String?
    let title: String?
    let description: String?
    let price: Double?
    let originalPrice: Double?
    let priceFormatted: String?
    let originalPriceFormatted: String?
    let currency: String?
    let url: String?
    let urlBehavior: String?
    let signalType: String?
    let minItemCount: Int?
    let maxItemCount: Int?
    let preSelectedQuantity: Int?
    let providerData: String?
    let linkedProductId: String?
    let quantityMustBeSynchronized: Bool?
    let images: [String: SelectImage]?
    let token: String?

    enum CodingKeys: String, CodingKey {
        case catalogItemId = "catalog_item_id"
        case instanceGuid = "instance_guid"
        case cartItemId = "cart_item_id"
        case title
        case description
        case price
        case originalPrice = "original_price"
        case priceFormatted = "price_formatted"
        case originalPriceFormatted = "original_price_formatted"
        case currency
        case url
        case urlBehavior = "url_behavior"
        case signalType = "signal_type"
        case minItemCount = "min_item_count"
        case maxItemCount = "max_item_count"
        case preSelectedQuantity = "pre_selected_quantity"
        case providerData = "provider_data"
        case linkedProductId = "linked_product_id"
        case quantityMustBeSynchronized = "quantity_must_be_synchronized"
        case images
        case token
    }
}

internal struct SelectCreative: Decodable, Equatable {
    let referralCreativeId: String?
    let instanceGuid: String?
    let token: String?
    let responseOptionsMap: [String: SelectResponseOption]?
    let copy: [String: String]?
    let images: [String: SelectImage]?
    let links: [String: SelectLink]?
    let icons: [String: SelectIcon]?

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

internal struct SelectResponseOption: Decodable, Equatable {
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

internal struct SelectImage: Decodable, Equatable {
    let light: String?
    let dark: String?
    let alt: String?
    let title: String?
}

internal struct SelectLink: Decodable, Equatable {
    let url: String?
    let title: String?
}

internal struct SelectIcon: Decodable, Equatable {
    let name: String?
}

/// Token lookup for a trackable entity, echoed back on events.
internal struct SelectEventDataEntry: Decodable, Equatable {
    let token: String
    let events: [String: SelectRealTimeEvent]?
}

/// A pre-serialized real-time event payload, keyed by signal type. Mirrors the
/// provider's typed event shape (and Android's `SelectRealTimeEvent`).
internal struct SelectRealTimeEvent: Decodable, Equatable, RealTimeEventSignal {
    let eventType: String?
    let payload: String?

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case payload
    }
}
