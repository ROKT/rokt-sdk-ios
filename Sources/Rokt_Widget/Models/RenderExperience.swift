// periphery:ignore:all - offers render encoder; encode-only
import Foundation

/// Encodes a ``SelectResponse`` into the renderer's experience JSON
/// (`RoktUXExperienceResponse`, camelCase) in a single pass, with no parallel
/// model tree. The pre-serialized DCUI layout-schema strings pass through
/// verbatim; the offer/creative subtree is re-homed from the response's
/// snake_case to the renderer's camelCase contract.
///
/// Field presence matches the renderer's decode contract: required keys are
/// always emitted (defaulting to `""` / `[]` / `{}`), optional keys are omitted
/// when absent. The renderer decodes with a plain `JSONDecoder` (no key
/// strategy), so the keys written here must match its property names verbatim.
internal struct RenderExperience: Encodable {
    private let response: SelectResponse

    init(_ response: SelectResponse) {
        self.response = response
    }

    /// Dynamic string coding key so the whole render contract is expressed with
    /// literal key names, without a coding-key enum per nested shape.
    private struct Key: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(_ stringValue: String) { self.stringValue = stringValue }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(response.sessionId, forKey: Key("sessionId"))
        try container.encode(response.sessionToken.token, forKey: Key("token"))

        var page = container.nestedContainer(keyedBy: Key.self, forKey: Key("page"))
        try page.encodeIfPresent(response.pageContext?.pageId, forKey: Key("pageId"))

        var placementContext = container.nestedContainer(keyedBy: Key.self, forKey: Key("placementContext"))
        // roktTagId is not in the response; required by the decoder but unused when rendering.
        try placementContext.encode("", forKey: Key("roktTagId"))
        try placementContext.encode(
            response.pageContext?.pageInstanceGuid ?? response.pageInstanceGuid,
            forKey: Key("pageInstanceGuid")
        )
        try placementContext.encode(
            response.pageContext?.token ?? response.sessionToken.token,
            forKey: Key("token")
        )

        // The render path uses plugins; placements stays empty but the key is required.
        try container.encode([String](), forKey: Key("placements"))

        if let plugins = response.plugins {
            var pluginsContainer = container.nestedUnkeyedContainer(forKey: Key("plugins"))
            for select in plugins {
                var box = pluginsContainer.nestedContainer(keyedBy: Key.self)
                var plugin = box.nestedContainer(keyedBy: Key.self, forKey: Key("plugin"))
                try Self.encodePlugin(select.plugin, into: &plugin)
            }
        }
    }

    private static func encodePlugin(
        _ layout: SelectPluginLayout?,
        into container: inout KeyedEncodingContainer<Key>
    ) throws {
        try container.encode(layout?.id ?? "", forKey: Key("id"))
        try container.encodeIfPresent(layout?.name, forKey: Key("name"))
        try container.encodeIfPresent(layout?.targetElementSelector, forKey: Key("targetElementSelector"))

        var config = container.nestedContainer(keyedBy: Key.self, forKey: Key("config"))
        let selectConfig = layout?.config
        try config.encodeIfPresent(selectConfig?.instanceGuid, forKey: Key("instanceGuid"))
        try config.encode(selectConfig?.token ?? "", forKey: Key("token"))
        // Pre-serialized DCUI schema — passed through verbatim.
        try config.encode(selectConfig?.outerLayoutSchema ?? "", forKey: Key("outerLayoutSchema"))

        var slots = config.nestedUnkeyedContainer(forKey: Key("slots"))
        for slot in selectConfig?.slots ?? [] {
            var slotContainer = slots.nestedContainer(keyedBy: Key.self)
            try Self.encodeSlot(slot, into: &slotContainer)
        }
    }

    private static func encodeSlot(
        _ slot: SelectSlot,
        into container: inout KeyedEncodingContainer<Key>
    ) throws {
        try container.encodeIfPresent(slot.instanceGuid, forKey: Key("instanceGuid"))
        try container.encode(slot.token ?? "", forKey: Key("token"))

        if let layoutVariant = slot.layoutVariant {
            var lv = container.nestedContainer(keyedBy: Key.self, forKey: Key("layoutVariant"))
            try lv.encode(layoutVariant.moduleName ?? "", forKey: Key("moduleName"))
            // Pre-serialized DCUI schema — passed through verbatim.
            try lv.encode(layoutVariant.layoutVariantSchema ?? "", forKey: Key("layoutVariantSchema"))
        }

        // An offer is only renderable with a creative; drop the key entirely otherwise.
        if let offer = slot.offer, let creative = offer.creative {
            var offerContainer = container.nestedContainer(keyedBy: Key.self, forKey: Key("offer"))
            try offerContainer.encodeIfPresent(offer.campaignId, forKey: Key("campaignId"))
            var creativeContainer = offerContainer.nestedContainer(keyedBy: Key.self, forKey: Key("creative"))
            try Self.encodeCreative(creative, into: &creativeContainer)
            // Shoppable/instant-purchase catalog content; without it the overlay renders blank.
            if let catalogItems = offer.catalogItems {
                var items = offerContainer.nestedUnkeyedContainer(forKey: Key("catalogItems"))
                for item in catalogItems {
                    var itemContainer = items.nestedContainer(keyedBy: Key.self)
                    try Self.encodeCatalogItem(item, into: &itemContainer)
                }
            }
        }
    }

    private static func encodeCreative(
        _ creative: SelectCreative,
        into container: inout KeyedEncodingContainer<Key>
    ) throws {
        try container.encode(creative.referralCreativeId ?? "", forKey: Key("referralCreativeId"))
        try container.encode(creative.instanceGuid ?? "", forKey: Key("instanceGuid"))
        try container.encode(creative.token ?? "", forKey: Key("token"))
        try container.encode(creative.copy ?? [:], forKey: Key("copy"))
        if let images = creative.images {
            try Self.encodeImages(images, into: &container, forKey: "images")
        }
        if let links = creative.links {
            var linksContainer = container.nestedContainer(keyedBy: Key.self, forKey: Key("links"))
            for (name, link) in links {
                var linkContainer = linksContainer.nestedContainer(keyedBy: Key.self, forKey: Key(name))
                try linkContainer.encodeIfPresent(link.url, forKey: Key("url"))
                try linkContainer.encodeIfPresent(link.title, forKey: Key("title"))
            }
        }
        // icons have no render-side target; intentionally dropped.
        try Self.encodeResponseOptions(creative.responseOptionsMap, into: &container)
    }

    /// The renderer keys response options positionally as `positive`/`negative`, not
    /// by the response's map key — options are bucketed on ``SelectResponseOption/isPositive``.
    private static func encodeResponseOptions(
        _ optionsMap: [String: SelectResponseOption]?,
        into container: inout KeyedEncodingContainer<Key>
    ) throws {
        guard let optionsMap else { return }
        var positive: SelectResponseOption?
        var negative: SelectResponseOption?
        for option in optionsMap.values.sorted(by: { $0.id ?? "" < $1.id ?? "" }) {
            if option.isPositive {
                positive = positive ?? option
            } else {
                negative = negative ?? option
            }
        }
        guard positive != nil || negative != nil else { return }
        var map = container.nestedContainer(keyedBy: Key.self, forKey: Key("responseOptionsMap"))
        if let positive {
            var slot = map.nestedContainer(keyedBy: Key.self, forKey: Key("positive"))
            try Self.encodeResponseOption(positive, into: &slot)
        }
        if let negative {
            var slot = map.nestedContainer(keyedBy: Key.self, forKey: Key("negative"))
            try Self.encodeResponseOption(negative, into: &slot)
        }
    }

    private static func encodeResponseOption(
        _ option: SelectResponseOption,
        into container: inout KeyedEncodingContainer<Key>
    ) throws {
        try container.encode(option.id ?? "", forKey: Key("id"))
        try container.encode(option.instanceGuid ?? "", forKey: Key("instanceGuid"))
        try container.encode(option.token ?? "", forKey: Key("token"))
        try container.encodeIfPresent(option.action, forKey: Key("action"))
        try container.encodeIfPresent(option.signalType, forKey: Key("signalType"))
        try container.encodeIfPresent(option.shortLabel, forKey: Key("shortLabel"))
        try container.encodeIfPresent(option.longLabel, forKey: Key("longLabel"))
        try container.encodeIfPresent(option.shortSuccessLabel, forKey: Key("shortSuccessLabel"))
        try container.encode(option.isPositive, forKey: Key("isPositive"))
        try container.encodeIfPresent(option.url, forKey: Key("url"))
    }

    /// A shoppable catalog item, re-homed to the renderer's camelCase `CatalogItem`
    /// contract. Fields the renderer requires but the response can omit are defaulted
    /// so the item always decodes; `positiveResponseText`/`negativeResponseText` are
    /// required by the renderer's model yet read nowhere, so they default to empty.
    private static func encodeCatalogItem(
        _ item: SelectCatalogItem,
        into container: inout KeyedEncodingContainer<Key>
    ) throws {
        try container.encode(item.catalogItemId ?? "", forKey: Key("catalogItemId"))
        try container.encode(item.cartItemId ?? "", forKey: Key("cartItemId"))
        try container.encode(item.instanceGuid ?? "", forKey: Key("instanceGuid"))
        try container.encode(item.title ?? "", forKey: Key("title"))
        try container.encode(item.description ?? "", forKey: Key("description"))
        try container.encodeIfPresent(item.price, forKey: Key("price"))
        try container.encodeIfPresent(item.priceFormatted, forKey: Key("priceFormatted"))
        try container.encodeIfPresent(item.originalPrice, forKey: Key("originalPrice"))
        try container.encodeIfPresent(item.originalPriceFormatted, forKey: Key("originalPriceFormatted"))
        try container.encode(item.currency ?? "", forKey: Key("currency"))
        try container.encodeIfPresent(item.signalType, forKey: Key("signalType"))
        try container.encodeIfPresent(item.url, forKey: Key("url"))
        try container.encodeIfPresent(item.urlBehavior, forKey: Key("urlBehavior"))
        try container.encodeIfPresent(item.minItemCount, forKey: Key("minItemCount"))
        try container.encodeIfPresent(item.maxItemCount, forKey: Key("maxItemCount"))
        try container.encodeIfPresent(item.preSelectedQuantity, forKey: Key("preSelectedQuantity"))
        try container.encode(item.providerData ?? "", forKey: Key("providerData"))
        try container.encodeIfPresent(item.linkedProductId, forKey: Key("linkedProductId"))
        // Required by the renderer's CatalogItem but consumed nowhere; empty is safe.
        try container.encode("", forKey: Key("positiveResponseText"))
        try container.encode("", forKey: Key("negativeResponseText"))
        try Self.encodeImages(item.images ?? [:], into: &container, forKey: "images")
        try container.encode(item.token ?? "", forKey: Key("token"))
    }

    private static func encodeImages(
        _ images: [String: SelectImage],
        into container: inout KeyedEncodingContainer<Key>,
        forKey key: String
    ) throws {
        var map = container.nestedContainer(keyedBy: Key.self, forKey: Key(key))
        for (name, image) in images {
            var imageContainer = map.nestedContainer(keyedBy: Key.self, forKey: Key(name))
            try imageContainer.encodeIfPresent(image.light, forKey: Key("light"))
            try imageContainer.encodeIfPresent(image.dark, forKey: Key("dark"))
            try imageContainer.encodeIfPresent(image.alt, forKey: Key("alt"))
            try imageContainer.encodeIfPresent(image.title, forKey: Key("title"))
        }
    }
}
