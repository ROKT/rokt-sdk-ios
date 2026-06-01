import XCTest
import SwiftUI
import ViewInspector
@testable import RoktUXHelper
import DcuiSchema

@available(iOS 15.0, *)
final class TestImageCarouselComponent: XCTestCase {

    func test_data_image() throws {
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.dataImageCarousel(try get_model()))

        let image = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(DataImageCarouselComponent.self)
            .actualView()

        XCTAssertNotNil(image)
    }

    func test_data_image_carousel_with_fallback() throws {
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.dataImageCarousel(try get_model(isFallback: true)))

         let image = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(DataImageCarouselComponent.self)
            .actualView()

        XCTAssertNotNil(image)
    }

    func get_model(isFallback: Bool = false) throws -> DataImageCarouselViewModel {

        let transformer = LayoutTransformer(
            layoutPlugin: get_mock_layout_plugin(slots: [get_slot()])
        )
        return try transformer.getDataImageCarousel(
            isFallback ? ModelTestData.DataImageCarouselData.dataImageCarouselWithFallback() : ModelTestData.DataImageCarouselData
                .dataImageCarousel(),
            context: .inner(.generic(get_slot().offer!))
        )
    }

    func get_slot() -> SlotModel {
        let image = "https://www.rokt.com"
        return SlotModel(instanceGuid: "",
                         offer: OfferModel(campaignId: "", creative:
                                            CreativeModel(referralCreativeId: "",
                                                          instanceGuid: "",
                                                          copy: [:],
                                                          images: [
                                                              "creativeCarouselImageVertical.1": CreativeImage(
                                                                  light: image,
                                                                  dark: nil, alt: "",
                                                                  title: nil
                                                              ),
                                                              "creativeCarouselImageVertical.2": CreativeImage(
                                                                  light: image,
                                                                  dark: nil, alt: "",
                                                                  title: nil
                                                              )
                                                          ],
                                                          links: nil,
                                                          responseOptionsMap: nil,
                                                          jwtToken: "creative-token"),
                                           catalogItems: nil,
                                           catalogItemGroup: nil,
                                           transactionData: nil),
                         layoutVariant: nil,
                         jwtToken: "slot-token")
    }
}
