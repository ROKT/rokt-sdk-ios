import Foundation
import DcuiSchema

@available(iOS 13, *)
protocol PluginResponse {
    func getOuterLayoutSchema(plugins: [PluginWrapperModel]?) -> OuterLayoutSchemaNetworkModel?
    func getAllInnerlayoutSchema(plugins: [PluginWrapperModel]?) -> [LayoutSchemaModel]?
    func getPlugins(plugins: [PluginWrapperModel]?) -> [LayoutPlugin]
}

@available(iOS 13, *)
extension PluginResponse {
    func getOuterLayoutSchema(plugins: [PluginWrapperModel]?) -> OuterLayoutSchemaNetworkModel? {
        plugins?.first?.plugin.config.outerLayoutSchema
    }

    func getAllInnerlayoutSchema(plugins: [PluginWrapperModel]?) -> [LayoutSchemaModel]? {
        guard let slots = plugins?.first?.plugin.config.slots else { return nil }

        return slots.compactMap { $0.layoutVariant?.layoutVariantSchema }
    }

    func getPlugins(plugins: [PluginWrapperModel]?) -> [LayoutPlugin] {
        var layoutPlugins = [LayoutPlugin]()

        guard let plugins else { return layoutPlugins }

        for pluginItem in plugins {
            guard let pluginConfigJWTToken = pluginItem.plugin.configJWTToken else { continue }

            let outerLayer = pluginItem.plugin.config.outerLayoutSchema
            let layoutPlugin = LayoutPlugin(pluginInstanceGuid: pluginItem.plugin.config.instanceGuid ?? "",
                                            breakpoints: outerLayer?.breakpoints,
                                            settings: outerLayer?.settings,
                                            layout: outerLayer?.layout,
                                            slots: pluginItem.plugin.config.slots ?? [],
                                            targetElementSelector: pluginItem.plugin.targetElementSelector,
                                            pluginConfigJWTToken: pluginConfigJWTToken,
                                            pluginId: pluginItem.plugin.id,
                                            pluginName: pluginItem.plugin.name)
            layoutPlugins.append(layoutPlugin)
        }

        return layoutPlugins
    }
}
