import XCTest

enum ProductCarouselFixture {
    static func data() throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "offers_product_carousel", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    static func string() throws -> String {
        try XCTUnwrap(String(data: data(), encoding: .utf8))
    }
}
