import XCTest

enum ProductCarouselFixture {
    static func data() throws -> Data {
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: resource("offers_product_carousel")) as? [String: Any])
        var plugins = try XCTUnwrap(root["plugins"] as? [[String: Any]])
        var plugin = try XCTUnwrap(plugins.first?["plugin"] as? [String: Any])
        var config = try XCTUnwrap(plugin["config"] as? [String: Any])
        config["outer_layout_schema"] = try schema(named: XCTUnwrap(config["outer_layout_schema"] as? String))
        var slots = try XCTUnwrap(config["slots"] as? [[String: Any]])
        for index in slots.indices {
            var variant = try XCTUnwrap(slots[index]["layout_variant"] as? [String: Any])
            variant["layout_variant_schema"] = try schema(named: XCTUnwrap(variant["layout_variant_schema"] as? String))
            slots[index]["layout_variant"] = variant
        }
        config["slots"] = slots
        plugin["config"] = config
        plugins[0]["plugin"] = plugin
        root["plugins"] = plugins
        return try JSONSerialization.data(withJSONObject: root, options: .sortedKeys)
    }

    static func string() throws -> String {
        try XCTUnwrap(String(data: data(), encoding: .utf8))
    }

    private static func schema(named name: String) throws -> String {
        try JSONDecoder().decode([String].self, from: resource(name)).joined()
    }

    private static func resource(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }
}
