import XCTest
@testable import RoktUXHelper

@available(iOS 15, *)
final class TextModelTests: XCTestCase {
    func test_styledText_text_model_uppercase() {
        let sut = ModelTestData.TextData.uppercase()
        let textUIModel = RichTextViewModel(value: sut.value, defaultStyle: sut.styles?.elements?.own.compactMap{ $0.default },
                                            openLinks: nil, layoutState: LayoutState(),
                                            eventService: nil)
        textUIModel.updateBoundValueWithStyling()
        XCTAssertEqual(textUIModel.boundValue, "ORDER NUMBER: UK171359906")
    }
    
    func test_styledText_text_model_lowerCase() {
        let sut = ModelTestData.TextData.lowercase()
        let textUIModel = RichTextViewModel(value: sut.value, defaultStyle: sut.styles?.elements?.own.compactMap{ $0.default },
                                            openLinks: nil, 
                                            layoutState: LayoutState(),
                                            eventService: nil)
        textUIModel.updateBoundValueWithStyling()
        XCTAssertEqual(textUIModel.boundValue, "order number: uk171359906")
    }
    
    func test_styledText_text_model_none() {
        let sut = ModelTestData.TextData.none()
        let textUIModel = RichTextViewModel(value: sut.value, defaultStyle: sut.styles?.elements?.own.compactMap{ $0.default },
                                            openLinks: nil,
                                            layoutState: LayoutState(),
                                            eventService: nil)
        textUIModel.updateBoundValueWithStyling()
        XCTAssertEqual(textUIModel.boundValue, "ORDER Number: Uk171359906")
    }
    
    func test_styledText_text_model_capitalize() {
        let sut = ModelTestData.TextData.capitalize()
        let textUIModel = RichTextViewModel(value: sut.value, 
                                            defaultStyle: sut.styles?.elements?.own.compactMap{ $0.default },
                                            openLinks: nil, 
                                            layoutState: LayoutState(),
                                            eventService: nil)
        textUIModel.updateBoundValueWithStyling()
        XCTAssertEqual(textUIModel.boundValue, "Order Number: Uk171359906")
    }
    
    func test_styledText_text_model_default_none() {
        let sut = ModelTestData.TextData.noValue()
        let textUIModel = RichTextViewModel(value: sut.value, defaultStyle: sut.styles?.elements?.own.compactMap{ $0.default },
                                            openLinks: nil, 
                                            layoutState: LayoutState(),
                                            eventService: nil)
        textUIModel.updateBoundValueWithStyling()
        XCTAssertEqual(textUIModel.boundValue, "OrDeR Number: Uk171359906")
    }
}
