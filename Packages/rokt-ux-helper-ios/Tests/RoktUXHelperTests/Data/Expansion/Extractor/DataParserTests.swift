import XCTest
@testable import RoktUXHelper

final class DataParserTests: XCTestCase {
    var sut: PropertyChainDataParsing!

    override func setUp() {
        super.setUp()

        sut = PropertyChainDataParser()
    }

    override func tearDown() {
        sut = nil

        super.tearDown()
    }

    func test_parse_withValidCreativeCopyPropertyChain_returnsCompleteBNFPlaceholder() {
        XCTAssertEqual(

            sut.parse(propertyChain: "%^DATA.creativeCopy.owner.pet.name|Spotty^%"),
            BNFPlaceholder(parseableChains: [BNFKeyAndNamespace(key: "owner.pet.name", namespace: .dataCreativeCopy)],
                           defaultValue: "Spotty")
        )
    }

    func test_parse_withValidCreativeResponsePropertyChain_returnsCompleteBNFPlaceholder() {
        XCTAssertEqual(
            sut.parse(propertyChain: "%^DATA.creativeResponse.owner.pet.name|Spotty^%"),
            BNFPlaceholder(parseableChains: [BNFKeyAndNamespace(key: "owner.pet.name", namespace: .dataCreativeResponse)],
                           defaultValue: "Spotty")
        )
    }

    func test_parse_withoutNamespaceInPropertyChain_returnsEmptyParseableChainsInBNFPlaceholder() {
        XCTAssertEqual(
            sut.parse(propertyChain: "%^house.owner.pet.name|Spotty^%"),
            BNFPlaceholder(parseableChains: [],
                           defaultValue: "Spotty")
        )
    }

    func test_parse_withoutDefaultValueInPropertyChain_returnsNilDefaultValueInBNFPlaceholder() {
        XCTAssertEqual(
            sut.parse(propertyChain: "%^DATA.creativeCopy.owner.pet.name^%"),
            BNFPlaceholder(
                parseableChains: [BNFKeyAndNamespace(key: "owner.pet.name", namespace: .dataCreativeCopy, isMandatory: true)],
                defaultValue: nil
            )
        )
    }
}
