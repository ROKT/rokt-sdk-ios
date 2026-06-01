import XCTest
@testable import RoktUXHelper

@available(iOS 13, *)
final class CreativeDataExtractorTests: XCTestCase {
    var offer: OfferModel!
    var sut: CreativeDataExtractor? = CreativeDataExtractor()

    override func setUp() {
        super.setUp()

        offer = ModelTestData.PageModelData.withBNF().layoutPlugins?.first!.slots[0].offer!
        sut = CreativeDataExtractor()
    }

    override func tearDown() {
        sut = nil

        super.tearDown()
    }

    func test_extractDataRepresentedBy_usingValidImageCarouselPropertyChain_returnsNestedString() throws {
        try [
            ("DATA.creativeImage.creativeCarouselImageVertical.1.title", "vertical title 1"),
            ("DATA.creativeImage.creativeCarouselImageVertical.2.title", "vertical title 2"),
            ("DATA.creativeImage.creativeCarouselImageHorizontal.1.title", "horizontal title 1"),
            ("DATA.creativeImage.creativeCarouselImageHorizontal.2.title", "horizontal title 2"),
            ("DATA.creativeImage.creativeCarouselImageHorizontal.3.title", "horizontal title 3"),
            ("DATA.creativeImage.creativeCarouselImageHorizontal.1.alt", "horizontal alt 1"),
            ("DATA.creativeImage.creativeCarouselImageHorizontal.2.alt", "horizontal alt 2"),
            ("DATA.creativeImage.creativeCarouselImageHorizontal.3.alt", "horizontal alt 3"),
            ("DATA.creativeImage.creativeImage.title", "title"),
            ("DATA.creativeImage.creativeImage.alt", "alt")
        ].forEach { (input, output) in
            XCTAssertEqual(
                try sut?.extractDataRepresentedBy(
                    String.self,
                    propertyChain: input,
                    responseKey: nil,
                    from: offer
                ),
                .value(output)
            )
        }
    }

    func test_extractDataRepresentedBy_usingInvalidImageCarouselPropertyChain_thenThrowError() throws {
        do {
            _ = try sut?.extractDataRepresentedBy(
                String.self,
                propertyChain: "DATA.creativeImage.creativeCarousel",
                responseKey: nil,
                from: offer
            )
            XCTFail("Expected BNFPlaceholderError.mandatoryKeyEmpty to be thrown")
        } catch BNFPlaceholderError.mandatoryKeyEmpty {
            // Expected error, test passes
        } catch {
            XCTFail("Expected BNFPlaceholderError.mandatoryKeyEmpty but got \(error)")
        }
    }

    func test_extractDataRepresentedBy_usingValidCreativeCopyPropertyChain_returnsNestedString() {
        XCTAssertNoThrow(try sut?.extractDataRepresentedBy(
            String.self,
            propertyChain: "DATA.creativeCopy.creative.termsAndConditions.link",
            responseKey: nil,
            from: offer
        ))
        XCTAssertEqual(
            try sut?.extractDataRepresentedBy(
                String.self,
                propertyChain: "DATA.creativeCopy.creative.termsAndConditions.link",
                responseKey: nil,
                from: offer
            ),
            .value("my_t_and_cs_link")
        )
    }

    func test_extractDataRepresentedBy_usingValidCreativeResponsePropertyChain_returnsNestedString() {
        XCTAssertNoThrow(try sut?.extractDataRepresentedBy(
            String.self,
            propertyChain: "DATA.creativeResponse.shortSuccessLabel",
            responseKey: "positive",
            from: offer
        ))
        XCTAssertEqual(
            try sut?.extractDataRepresentedBy(
                String.self,
                propertyChain: "DATA.creativeResponse.shortSuccessLabel",
                responseKey: "positive",
                from: offer
            ),
            .value("Short Success Label!")
        )
    }

    func test_extractDataRepresentedBy_usingInvalidPropertyChain_returnsNestedString() {
        XCTAssertNoThrow(try sut?.extractDataRepresentedBy(
            String.self,
            propertyChain: "DATA.creative.missingTestId",
            responseKey: nil,
            from: offer
        ))
        XCTAssertEqual(
            try sut?.extractDataRepresentedBy(
                String.self,
                propertyChain: "DATA.creative.missingTestId",
                responseKey: nil,
                from: offer
            ),
            .value("DATA.creative.missingTestId")
        )
    }

    func test_extractDataRepresentedBy_usingValidCreativeLinkPropertyChain_returnsNestedString() {
        XCTAssertNoThrow(
            try sut?.extractDataRepresentedBy(
                String.self,
                propertyChain: "DATA.creativeLink.privacyPolicy",
                responseKey: nil,
                from: offer
            )
        )
        XCTAssertEqual(
            try sut?.extractDataRepresentedBy(
                String.self,
                propertyChain: "DATA.creativeLink.privacyPolicy",
                responseKey: nil,
                from: offer
            ),
            .value("<a href=\"https://rokt.com\" target=\"_blank\">Privacy Policy Link</a>")
        )
    }
}
