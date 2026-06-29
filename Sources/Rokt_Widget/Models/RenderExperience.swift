// periphery:ignore:all - offers render models; fields are encode-only
import Foundation

// MARK: - Renderer experience contract (camelCase)

/// The experience JSON the renderer decodes (`RoktUXExperienceResponse`), mapped
/// from the offers ``SelectResponse``. The pre-serialized DCUI layout-schema
/// strings pass through verbatim; the offer/creative subtree is re-homed from the
/// response's snake_case to the renderer's camelCase contract.
internal struct RenderExperience: Encodable {
    let sessionId: String
    let token: String
    let page: RenderPage
    let placementContext: RenderPlacementContext
    let placements: [RenderPlacement]
    let plugins: [RenderPluginContainer]?

    init(_ response: SelectResponse) {
        sessionId = response.sessionId
        token = response.sessionToken.token
        page = RenderPage(pageId: response.pageContext?.pageId)
        placementContext = RenderPlacementContext(response)
        // The render path uses plugins; placements stays empty but the key is required.
        placements = []
        plugins = response.plugins?.map(RenderPluginContainer.init)
    }
}

internal struct RenderPage: Encodable {
    let pageId: String?
}

internal struct RenderPlacementContext: Encodable {
    let roktTagId: String
    let pageInstanceGuid: String
    let token: String

    init(_ response: SelectResponse) {
        // Not in the response; required by the decoder but unused when rendering.
        roktTagId = ""
        pageInstanceGuid = response.pageContext?.pageInstanceGuid ?? response.pageInstanceGuid
        token = response.pageContext?.token ?? response.sessionToken.token
    }
}

/// Always empty — present only because the decoder requires the key.
internal struct RenderPlacement: Encodable {}

internal struct RenderPluginContainer: Encodable {
    let plugin: RenderPlugin

    init(_ plugin: SelectPlugin) {
        self.plugin = RenderPlugin(plugin.plugin)
    }
}

internal struct RenderPlugin: Encodable {
    let id: String
    let name: String?
    let targetElementSelector: String?
    let config: RenderPluginConfig

    init(_ layout: SelectPluginLayout?) {
        id = layout?.id ?? ""
        name = layout?.name
        targetElementSelector = layout?.targetElementSelector
        config = RenderPluginConfig(layout?.config)
    }
}

internal struct RenderPluginConfig: Encodable {
    let instanceGuid: String?
    let token: String
    let outerLayoutSchema: String
    let slots: [RenderSlot]

    init(_ config: SelectPluginConfig?) {
        instanceGuid = config?.instanceGuid
        token = config?.token ?? ""
        // Pre-serialized DCUI schema — passed through verbatim.
        outerLayoutSchema = config?.outerLayoutSchema ?? ""
        slots = (config?.slots ?? []).map(RenderSlot.init)
    }
}

internal struct RenderSlot: Encodable {
    let instanceGuid: String?
    let token: String
    let layoutVariant: RenderLayoutVariant?
    let offer: RenderOffer?

    init(_ slot: SelectSlot) {
        instanceGuid = slot.instanceGuid
        token = slot.token ?? ""
        layoutVariant = slot.layoutVariant.map(RenderLayoutVariant.init)
        offer = RenderOffer(slot.offer)
    }
}

internal struct RenderLayoutVariant: Encodable {
    let moduleName: String
    let layoutVariantSchema: String

    init(_ layoutVariant: SelectLayoutVariant) {
        moduleName = layoutVariant.moduleName ?? ""
        // Pre-serialized DCUI schema — passed through verbatim (empty -> dropped).
        layoutVariantSchema = layoutVariant.layoutVariantSchema ?? ""
    }
}

internal struct RenderOffer: Encodable {
    let campaignId: String?
    let creative: RenderCreative

    /// Nil when the slot carries no creative — an offer is only renderable with one.
    init?(_ offer: SelectOffer?) {
        guard let offer, let creative = offer.creative else { return nil }
        campaignId = offer.campaignId
        self.creative = RenderCreative(creative)
    }
}

internal struct RenderCreative: Encodable {
    let referralCreativeId: String
    let instanceGuid: String
    let token: String
    let copy: [String: String]
    let images: [String: RenderImage]?
    let links: [String: RenderLink]?
    let responseOptionsMap: RenderResponseOptionList?

    init(_ creative: SelectCreative) {
        referralCreativeId = creative.referralCreativeId ?? ""
        instanceGuid = creative.instanceGuid ?? ""
        token = creative.token ?? ""
        copy = creative.copy ?? [:]
        images = creative.images?.mapValues(RenderImage.init)
        links = creative.links?.mapValues(RenderLink.init)
        // icons have no render-side target; intentionally dropped.
        responseOptionsMap = RenderResponseOptionList(creative.responseOptionsMap)
    }
}

internal struct RenderImage: Encodable {
    let light: String?
    let dark: String?
    let alt: String?
    let title: String?

    init(_ image: SelectImage) {
        light = image.light
        dark = image.dark
        alt = image.alt
        title = image.title
    }
}

internal struct RenderLink: Encodable {
    let url: String?
    let title: String?

    init(_ link: SelectLink) {
        url = link.url
        title = link.title
    }
}

/// The renderer keys response options positionally as `positive`/`negative`, not by
/// the response's map key — so options are bucketed on ``SelectResponseOption/isPositive``.
internal struct RenderResponseOptionList: Encodable {
    let positive: RenderResponseOption?
    let negative: RenderResponseOption?

    init?(_ optionsMap: [String: SelectResponseOption]?) {
        guard let optionsMap else { return nil }
        var positive: RenderResponseOption?
        var negative: RenderResponseOption?
        for option in optionsMap.values.sorted(by: { $0.id ?? "" < $1.id ?? "" }) {
            if option.isPositive {
                positive = positive ?? RenderResponseOption(option)
            } else {
                negative = negative ?? RenderResponseOption(option)
            }
        }
        guard positive != nil || negative != nil else { return nil }
        self.positive = positive
        self.negative = negative
    }
}

internal struct RenderResponseOption: Encodable {
    let id: String
    let instanceGuid: String
    let token: String
    let action: String?
    let signalType: String?
    let shortLabel: String?
    let longLabel: String?
    let shortSuccessLabel: String?
    let isPositive: Bool
    let url: String?

    init(_ option: SelectResponseOption) {
        id = option.id ?? ""
        instanceGuid = option.instanceGuid ?? ""
        token = option.token ?? ""
        action = option.action
        signalType = option.signalType
        shortLabel = option.shortLabel
        longLabel = option.longLabel
        shortSuccessLabel = option.shortSuccessLabel
        isPositive = option.isPositive
        url = option.url
    }
}
