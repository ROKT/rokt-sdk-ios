import Foundation
@testable import RoktUXHelper
import DcuiSchema

class ModelTestData: NSObject {
    enum TextData {
        static func uppercase() -> RichTextModel<WhenPredicate> {
            let data = toData(jsonFilename: "node_text_uppercase")
            return try! JSONDecoder().decode(RichTextModel.self, from: data)
        }

        static func lowercase() -> RichTextModel<WhenPredicate> {
            let data = toData(jsonFilename: "node_text_lowercase")
            return try! JSONDecoder().decode(RichTextModel.self, from: data)
        }

        static func capitalize() -> RichTextModel<WhenPredicate> {
            let data = toData(jsonFilename: "node_text_capitalize")
            return try! JSONDecoder().decode(RichTextModel.self, from: data)
        }

        static func none() -> RichTextModel<WhenPredicate> {
            let data = toData(jsonFilename: "node_text_none")
            return try! JSONDecoder().decode(RichTextModel.self, from: data)
        }

        static func noValue() -> RichTextModel<WhenPredicate> {
            let data = toData(jsonFilename: "node_text_no_value")
            return try! JSONDecoder().decode(RichTextModel.self, from: data)
        }

        static func superscriptTransform() -> RichTextModel<WhenPredicate> {
            let data = toData(jsonFilename: "node_text_superscript")
            return try! JSONDecoder().decode(RichTextModel.self, from: data)
        }

        static func subscriptTransform() -> RichTextModel<WhenPredicate> {
            let data = toData(jsonFilename: "node_text_subscript")
            return try! JSONDecoder().decode(RichTextModel.self, from: data)
        }
        
        static func basicText() -> BasicTextModel<WhenPredicate> {
            let data = toData(jsonFilename: "node_text_none")
            return try! JSONDecoder().decode(BasicTextModel.self, from: data)
        }     
        
        static func richTextOuterLayer() -> LayoutSchemaModel {
            let data = toData(jsonFilename: "node_text_none")
            let richText = try! JSONDecoder().decode(RichTextModel<WhenPredicate>.self, from: data)
            return LayoutSchemaModel.richText(richText)
        }

        static func richTextHTML() -> RichTextModel<WhenPredicate> {
            let data = toData(jsonFilename: "node_richtext_html")
            return try! JSONDecoder().decode(RichTextModel.self, from: data)
        }
        
        static func richTextState() -> RichTextModel<WhenPredicate> {
            let data = toData(jsonFilename: "node_richtext_state")
            return try! JSONDecoder().decode(RichTextModel.self, from: data)
        }
    }
    
    enum CreativeResponseData {
        static func positive() -> CreativeResponseModel<LayoutSchemaModel, WhenPredicate>? {
            let data = toData(jsonFilename: "node_creative_response_positive")
            let layout = try! JSONDecoder().decode(LayoutSchemaModel.self, from: data)
            guard case .creativeResponse(let model) = layout else { return nil }
            return model
        }
        
        static func negative() -> CreativeResponseModel<LayoutSchemaModel, WhenPredicate>? {
            let data = toData(jsonFilename: "node_creative_response_negative")
            let layout = try! JSONDecoder().decode(LayoutSchemaModel.self, from: data)
            guard case .creativeResponse(let model) = layout else { return nil }
            return model
        }
                
        static func neutral() -> CreativeResponseModel<LayoutSchemaModel, WhenPredicate>? {
            let data = toData(jsonFilename: "node_creative_response_neutral")
            let layout = try! JSONDecoder().decode(LayoutSchemaModel.self, from: data)
            guard case .creativeResponse(let model) = layout else { return nil }
            return model
        }
    }
    
    enum CloseButtonData {
        static func closeButton() -> CloseButtonModel<LayoutSchemaModel, WhenPredicate> {
            let data = toData(jsonFilename: "node_close_button")
            return try! JSONDecoder().decode(CloseButtonModel<LayoutSchemaModel, WhenPredicate>.self, from: data)
        }
    }    
    
    enum ProgressControlData {
        static func progressControl() -> ProgressControlModel<LayoutSchemaModel, WhenPredicate> {
            let data = toData(jsonFilename: "node_progress_control")
            return try! JSONDecoder().decode(ProgressControlModel<LayoutSchemaModel, WhenPredicate>.self, from: data)
        }
    }
    
    enum RowData {
        static func rowWithBasicText() -> RowModel<LayoutSchemaModel, WhenPredicate> {
            let data = toData(jsonFilename: "node_row_with_basic_text")
            return try! JSONDecoder().decode(RowModel<LayoutSchemaModel, WhenPredicate>.self, from: data)
        }
        static func rowWithChildren() -> RowModel<LayoutSchemaModel, WhenPredicate> {
            let data = toData(jsonFilename: "node_row_with_children")
            return try! JSONDecoder().decode(RowModel<LayoutSchemaModel, WhenPredicate>.self, from: data)
        }
        static func accessibilityGroupedRow() -> AccessibilityGroupedModel<AccessibilityGroupedLayoutChildren> {
            let data = toData(jsonFilename: "node_accessibility_grouped_row")
            return try! JSONDecoder().decode(AccessibilityGroupedModel<AccessibilityGroupedLayoutChildren>.self, from: data)
        }
        static func scrollableRowWithMaxWidth() -> RowModel<LayoutSchemaModel, WhenPredicate> {
            let data = toData(jsonFilename: "node_scrollable_row_with_max_width")
            return try! JSONDecoder().decode(RowModel<LayoutSchemaModel, WhenPredicate>.self, from: data)
        }
    }
    enum ColumnData {
        static func columnWithBasicText() -> ColumnModel<LayoutSchemaModel, WhenPredicate> {
            let data = toData(jsonFilename: "node_column_with_basic_text")
            return try! JSONDecoder().decode(ColumnModel<LayoutSchemaModel, WhenPredicate>.self, from: data)
        }
        static func columnWithOverflow() -> ColumnModel<LayoutSchemaModel, WhenPredicate> {
            let data = toData(jsonFilename: "node_column_with_overflow_scroll")
            return try! JSONDecoder().decode(ColumnModel<LayoutSchemaModel, WhenPredicate>.self, from: data)
        }
        static func accessibilityGroupedColumn() -> AccessibilityGroupedModel<AccessibilityGroupedLayoutChildren> {
            let data = toData(jsonFilename: "node_accessibility_grouped_column")
            return try! JSONDecoder().decode(AccessibilityGroupedModel<AccessibilityGroupedLayoutChildren>.self, from: data)
        }
        static func columnWithOffset() -> ColumnModel<LayoutSchemaModel, WhenPredicate> {
            let data = toData(jsonFilename: "node_column_with_offset")
            return try! JSONDecoder().decode(ColumnModel<LayoutSchemaModel, WhenPredicate>.self, from: data)
        }
        static func scrollableColumnWithMaxHeight() -> ColumnModel<LayoutSchemaModel, WhenPredicate> {
            let data = toData(jsonFilename: "node_scrollable_column_with_max_height")
            return try! JSONDecoder().decode(ColumnModel<LayoutSchemaModel, WhenPredicate>.self, from: data)
        }
    }
    
    enum ZStackData {
        static func zStackWithStyles() -> ZStackModel<LayoutSchemaModel, WhenPredicate> {
            let data = toData(jsonFilename: "node_zstack_with_styles")
            return try! JSONDecoder().decode(ZStackModel<LayoutSchemaModel, WhenPredicate>.self, from: data)
        }
        
        static func accessibilityGroupedZStack() -> AccessibilityGroupedModel<AccessibilityGroupedLayoutChildren> {
            let data = toData(jsonFilename: "node_accessibility_grouped_zstack")
            return try! JSONDecoder().decode(AccessibilityGroupedModel<AccessibilityGroupedLayoutChildren>.self, from: data)
        }
    }
    
    enum OneByOneData {
        static func oneByOne() -> OneByOneDistributionModel<WhenPredicate>? {
            let data = toData(jsonFilename: "node_onebyone")
            let layout = try! JSONDecoder().decode(LayoutSchemaModel.self, from: data)
            if case .oneByOneDistribution(let model) = layout {
                return model
            }
            return nil
        }
    }
    
    enum CarouselData {
        static func carousel() -> CarouselDistributionModel<WhenPredicate>? {
            let data = toData(jsonFilename: "node_carousel")
            let layout = try! JSONDecoder().decode(LayoutSchemaModel.self, from: data)
            if case .carouselDistribution(let model) = layout {
                return model
            }
            return nil
        }
    } 
    
    enum GroupedDistributionData {
        static func groupedDistribution() -> GroupedDistributionModel<WhenPredicate>? {
            let data = toData(jsonFilename: "node_grouped_distribution")
            let layout = try! JSONDecoder().decode(LayoutSchemaModel.self, from: data)
            if case .groupedDistribution(let model) = layout {
                return model
            }
            return nil
        }
    }
    
    enum StaticLinkData {
        static func staticLink() -> StaticLinkModel<LayoutSchemaModel, WhenPredicate> {
            let data = toData(jsonFilename: "node_static_link")
            return try! JSONDecoder().decode(StaticLinkModel<LayoutSchemaModel, WhenPredicate>.self, from: data)
        }
    }
    
    enum DataImageData {
        static func dataImage() -> DataImageModel<WhenPredicate> {
            let data = toData(jsonFilename: "node_data_image")
            return try! JSONDecoder().decode(DataImageModel.self, from: data)
        }
        static func dataImageWithFallback() -> DataImageModel<WhenPredicate> {
            let data = toData(jsonFilename: "node_data_image_fallback")
            return try! JSONDecoder().decode(DataImageModel.self, from: data)
        }
    }
    
    enum DataImageCarouselData {
        static func dataImageCarousel() -> DataImageCarouselModel<WhenPredicate> {
            let data = toData(jsonFilename: "node_data_image_carousel")
            return try! JSONDecoder().decode(DataImageCarouselModel.self, from: data)
        }
        static func dataImageCarouselWithFallback() -> DataImageCarouselModel<WhenPredicate> {
            let data = toData(jsonFilename: "node_data_image_carousel_fallback")
            return try! JSONDecoder().decode(DataImageCarouselModel.self, from: data)
        }
    }

    enum StaticImageData {
        static func staticImage() -> StaticImageModel<WhenPredicate> {
            let data = toData(jsonFilename: "node_static_image")
            return try! JSONDecoder().decode(StaticImageModel.self, from: data)
        }        
        static func emptyURLImage() -> StaticImageModel<WhenPredicate> {
            let data = toData(jsonFilename: "node_static_image_empty_url")
            return try! JSONDecoder().decode(StaticImageModel.self, from: data)
        }
        
        static func withAlt() -> StaticImageModel<WhenPredicate> {
            let data = toData(jsonFilename: "node_static_image_with_alt")
            return try! JSONDecoder().decode(StaticImageModel.self, from: data)
        }
    }
    
    enum ProgressIndicatorData {
        static func progressIndicator() -> ProgressIndicatorModel<WhenPredicate> {
            let data = toData(jsonFilename: "node_progress_indicator")
            return try! JSONDecoder().decode(ProgressIndicatorModel.self, from: data)
        }

        static func progressIndicatorUI() -> ProgressIndicatorModel<WhenPredicate> {
            let data = toData(jsonFilename: "node_progress_indicator_ui")
            return try! JSONDecoder().decode(ProgressIndicatorModel.self, from: data)
        }

        static func invalidDataExpansion() -> ProgressIndicatorModel<WhenPredicate> {
            let data = toData(jsonFilename: "node_invalid_expansion_progress_indicator")
            return try! JSONDecoder().decode(ProgressIndicatorModel.self, from: data)
        }

        static func chainOfvaluesDataExpansion() -> ProgressIndicatorModel<WhenPredicate> {
            let data = toData(jsonFilename: "node_data_expansion_chain")
            return try! JSONDecoder().decode(ProgressIndicatorModel.self, from: data)
        }
        
        static func startPosition() -> ProgressIndicatorModel<WhenPredicate> {
            let data = toData(jsonFilename: "node_start_position_progress_indicator")
            return try! JSONDecoder().decode(ProgressIndicatorModel.self, from: data)
        }
        
        static func accessibilityHidden() -> ProgressIndicatorModel<WhenPredicate> {
            let data = toData(jsonFilename: "node_accessibilityHidden_progress_indicator")
            return try! JSONDecoder().decode(ProgressIndicatorModel.self, from: data)
        }
    }

    enum OverlayData {
        static func singleTextOverlay() -> OverlayModel<RichTextModel<WhenPredicate>, WhenPredicate> {
            let data = toData(jsonFilename: "overlay_test")
            return try! JSONDecoder().decode(OverlayModel.self, from: data)
        }       
        static func alignWrapperCenterOverlay() -> OverlayModel<RichTextModel<WhenPredicate>, WhenPredicate> {
            let data = toData(jsonFilename: "overlay_wrapper_center")
            return try! JSONDecoder().decode(OverlayModel.self, from: data)
        }
        static func alignSelfFlexEndOverlay() -> OverlayModel<RichTextModel<WhenPredicate>, WhenPredicate> {
            let data = toData(jsonFilename: "overlay_self_flexend")
            return try! JSONDecoder().decode(OverlayModel.self, from: data)
        }
    }
    
    enum ToggleButtonData {
        static func basicToggleButton() -> ToggleButtonStateTriggerModel<LayoutSchemaModel, WhenPredicate> {
            let data = toData(jsonFilename: "node_toggle_button")
            return try! JSONDecoder().decode(ToggleButtonStateTriggerModel<LayoutSchemaModel, WhenPredicate>.self, from: data)
        }

        static func toggleButtonWithLabel() -> ToggleButtonStateTriggerModel<LayoutSchemaModel, WhenPredicate> {
            let data = toData(jsonFilename: "node_toggle_button_with_label")
            return try! JSONDecoder().decode(ToggleButtonStateTriggerModel<LayoutSchemaModel, WhenPredicate>.self, from: data)
        }
    }
    
    enum CatalogDevicePayButtonData {
        static func catalogDevicePayButton() -> CatalogDevicePayButtonModel<LayoutSchemaModel, WhenPredicate> {
            let data = toData(jsonFilename: "node_catalog_device_pay")
            return try! JSONDecoder().decode(CatalogDevicePayButtonModel<LayoutSchemaModel, WhenPredicate>.self, from: data)
        }

        static func applePay() -> CatalogDevicePayButtonModel<LayoutSchemaModel, WhenPredicate> {
            let data = toData(jsonFilename: "node_catalog_device_pay_apple_pay")
            return try! JSONDecoder().decode(CatalogDevicePayButtonModel<LayoutSchemaModel, WhenPredicate>.self, from: data)
        }

        static func afterpay() -> CatalogDevicePayButtonModel<LayoutSchemaModel, WhenPredicate> {
            let data = toData(jsonFilename: "node_catalog_device_pay_afterpay")
            return try! JSONDecoder().decode(CatalogDevicePayButtonModel<LayoutSchemaModel, WhenPredicate>.self, from: data)
        }
    }

    enum CatalogResponseButtonData {
        static func catalogResponseButton() -> CatalogResponseButtonModel<LayoutSchemaModel, WhenPredicate> {
            let data = toData(jsonFilename: "node_catalog_response")
            return try! JSONDecoder().decode(CatalogResponseButtonModel<LayoutSchemaModel, WhenPredicate>.self, from: data)
        }
    }

    enum CatalogDropdownData {
        static func catalogDropdown() -> CatalogDropdownModel<WhenPredicate> {
            let data = toData(jsonFilename: "node_catalog_dropdown")
            return try! JSONDecoder().decode(CatalogDropdownModel<WhenPredicate>.self, from: data)
        }
    }

    @available(iOS 13, *)
    enum PageModelData {
        static func withBNF() -> RoktUXPageModel {
            let data = toData(jsonFilename: "page_model")
            let experienceResponse = try! JSONDecoder().decode(RoktUXS2SExperienceResponse.self, from: data)
            return experienceResponse.getPageModel()!
        }
        static func getJsonString(jsonFilename: String) -> String {
            let data = toData(jsonFilename: jsonFilename)
            if let jsonObject = try? JSONSerialization.jsonObject(with: data),
               let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
            return "{}"
        }
    }

    @available(iOS 13, *)
    enum CatalogPageModelData {
        static func withBNF() -> RoktUXPageModel {
            let data = toData(jsonFilename: "add_to_cart_page_model")
            let experienceResponse = try! JSONDecoder().decode(RoktUXS2SExperienceResponse.self, from: data)
            return experienceResponse.getPageModel()!
        }
    }

    static func toData(jsonFilename: String) -> Data {
        let bundle = Bundle.module
        let url = bundle.url(forResource: jsonFilename, withExtension: "json")!

        return try! (Data(contentsOf: url))
    }
}

class FakeObject: NSObject {}
