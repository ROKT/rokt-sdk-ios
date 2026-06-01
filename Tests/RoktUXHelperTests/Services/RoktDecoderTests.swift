import XCTest
@testable import RoktUXHelper

@available(iOS 13, *)
final class RoktDecoderTests: XCTestCase {

    func test_decode_withValidJSONString_returnsDecodedModel() throws {
        struct Fixture: Codable, Equatable {
            let name: String
            let count: Int
        }

        let sut = RoktDecoder()

        let decoded = try sut.decode(Fixture.self, #"{"name":"catalog","count":2}"#)

        XCTAssertEqual(decoded, Fixture(name: "catalog", count: 2))
    }

    func test_decode_withInvalidJSONString_throws() {
        struct Fixture: Codable {
            let name: String
        }

        let sut = RoktDecoder()

        XCTAssertThrowsError(try sut.decode(Fixture.self, #"{"name":}"#))
    }
}
