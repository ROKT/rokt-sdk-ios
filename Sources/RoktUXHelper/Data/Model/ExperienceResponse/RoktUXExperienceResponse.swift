import Foundation
import DcuiSchema

@available(iOS 13, *)
public class RoktUXExperienceResponse: RoktUXPlacementResponse, PluginResponse {
    var plugins: [PluginWrapperModel]?

    enum CodingKeys: String, CodingKey {
        case plugins
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        plugins = try container.decodeIfPresent([PluginWrapperModel].self, forKey: .plugins)

        try super.init(from: decoder)
    }

    public func getPageModel() -> RoktUXPageModel? {
        guard let outerLayer = getOuterLayoutSchema(plugins: plugins),
              outerLayer.layout != nil && getAllInnerlayoutSchema(plugins: plugins) != nil
        else { return nil }
        return RoktUXPageModel(
            pageId: page?.pageId,
            sessionId: sessionId,
            pageInstanceGuid: placementContext.pageInstanceGuid,
            layoutPlugins: getPlugins(plugins: plugins),
            token: placementContext.placementContextJWTToken,
            options: .some([.useDiagnosticEvents])
        )
    }
}
