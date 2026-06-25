// periphery:ignore:all - offers render adapter
import Foundation

/// Adapts the offers ``SelectResponse`` into the experience JSON string the
/// renderer decodes (`RoktUXExperienceResponse`). The pre-serialized DCUI
/// layout-schema strings pass through verbatim; the offer/creative subtree is
/// re-homed from the response's snake_case to the renderer's camelCase contract.
internal enum SelectExperienceAdapter {

    enum AdapterError: Error {
        case encodingFailed
    }

    static func experienceJSONString(from response: SelectResponse) throws -> String {
        let data = try JSONEncoder().encode(RenderExperience(response))
        guard let string = String(data: data, encoding: .utf8) else {
            throw AdapterError.encodingFailed
        }
        return string
    }
}

// MARK: - Renderer experience contract (camelCase)

private struct RenderExperience: Encodable {
    let sessionId: String
    let token: String
    let page: RenderPage
    let placementContext: RenderPlacementContext
    let placements: [RenderPlacement]
    let plugins: [RenderPluginContainer]?

    init(_ r: SelectResponse) {
        sessionId = r.sessionId
        token = r.sessionToken.token
        page = RenderPage(pageId: r.pageContext?.pageId)
        placementContext = RenderPlacementContext(r)
        // The render path uses plugins; placements stays empty but the key is required.
        placements = []
        plugins = r.plugins?.map(RenderPluginContainer.init)
    }
}

private struct RenderPage: Encodable {
    let pageId: String?
}

private struct RenderPlacementContext: Encodable {
    let roktTagId: String
    let pageInstanceGuid: String
    let token: String

    init(_ r: SelectResponse) {
        // Not in the response; required by the decoder but unused when rendering.
        roktTagId = ""
        pageInstanceGuid = r.pageContext?.pageInstanceGuid ?? r.pageInstanceGuid
        token = r.pageContext?.token ?? r.sessionToken.token
    }
}

/// Always empty — present only because the decoder requires the key.
private struct RenderPlacement: Encodable {}

private struct RenderPluginContainer: Encodable {
    let plugin: RenderPlugin

    init(_ p: SelectPlugin) {
        plugin = RenderPlugin(p.plugin)
    }
}

private struct RenderPlugin: Encodable {
    let id: String
    let name: String?
    let targetElementSelector: String?
    let config: RenderPluginConfig

    init(_ p: SelectPluginLayout?) {
        id = p?.id ?? ""
        name = p?.name
        targetElementSelector = p?.targetElementSelector
        config = RenderPluginConfig(p?.config)
    }
}

private struct RenderPluginConfig: Encodable {
    let instanceGuid: String?
    let token: String
    let outerLayoutSchema: String
    let slots: [RenderSlot]

    init(_ c: SelectPluginConfig?) {
        instanceGuid = c?.instanceGuid
        token = c?.token ?? ""
        // Pre-serialized DCUI schema — passed through verbatim.
        outerLayoutSchema = c?.outerLayoutSchema ?? ""
        slots = (c?.slots ?? []).map(RenderSlot.init)
    }
}

private struct RenderSlot: Encodable {
    let instanceGuid: String?
    let token: String
    let layoutVariant: RenderLayoutVariant?
    let offer: RenderOffer?

    init(_ s: SelectSlot) {
        instanceGuid = s.instanceGuid
        token = s.token ?? ""
        layoutVariant = s.layoutVariant.map(RenderLayoutVariant.init)
        offer = RenderOffer(s.offer)
    }
}

private struct RenderLayoutVariant: Encodable {
    let moduleName: String
    let layoutVariantSchema: String

    init(_ v: SelectLayoutVariant) {
        moduleName = v.moduleName ?? ""
        // Pre-serialized DCUI schema — passed through verbatim (empty -> dropped).
        layoutVariantSchema = v.layoutVariantSchema ?? ""
    }
}

private struct RenderOffer: Encodable {
    let campaignId: String?
    let creative: RenderCreative

    /// Nil when the slot carries no creative — an offer is only renderable with one.
    init?(_ o: SelectOffer?) {
        guard let o, let creative = o.creative else { return nil }
        campaignId = o.campaignId
        self.creative = RenderCreative(creative)
    }
}

private struct RenderCreative: Encodable {
    let referralCreativeId: String
    let instanceGuid: String
    let token: String
    let copy: [String: String]
    let images: [String: RenderImage]?
    let links: [String: RenderLink]?
    let responseOptionsMap: RenderResponseOptionList?

    init(_ c: SelectCreative) {
        referralCreativeId = c.referralCreativeId ?? ""
        instanceGuid = c.instanceGuid ?? ""
        token = c.token ?? ""
        copy = c.copy ?? [:]
        images = c.images?.mapValues(RenderImage.init)
        links = c.links?.mapValues(RenderLink.init)
        // icons have no render-side target; intentionally dropped.
        responseOptionsMap = RenderResponseOptionList(c.responseOptionsMap)
    }
}

private struct RenderImage: Encodable {
    let light: String?
    let dark: String?
    let alt: String?
    let title: String?

    init(_ i: SelectImage) {
        light = i.light
        dark = i.dark
        alt = i.alt
        title = i.title
    }
}

private struct RenderLink: Encodable {
    let url: String?
    let title: String?

    init(_ l: SelectLink) {
        url = l.url
        title = l.title
    }
}

/// The renderer keys response options positionally as `positive`/`negative`, not by
/// the response's map key — so options are bucketed on ``SelectResponseOption/isPositive``.
private struct RenderResponseOptionList: Encodable {
    let positive: RenderResponseOption?
    let negative: RenderResponseOption?

    init?(_ map: [String: SelectResponseOption]?) {
        guard let map else { return nil }
        var positive: RenderResponseOption?
        var negative: RenderResponseOption?
        for option in map.values.sorted(by: { $0.id ?? "" < $1.id ?? "" }) {
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

private struct RenderResponseOption: Encodable {
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

    init(_ o: SelectResponseOption) {
        id = o.id ?? ""
        instanceGuid = o.instanceGuid ?? ""
        token = o.token ?? ""
        action = o.action
        signalType = o.signalType
        shortLabel = o.shortLabel
        longLabel = o.longLabel
        shortSuccessLabel = o.shortSuccessLabel
        isPositive = o.isPositive
        url = o.url
    }
}
