import XCTest
@testable import RoktUXHelper
import DcuiSchema

@available(iOS 15, *)
final class TestStyleTransformer: XCTestCase {
    
    func test_get_updated_style_styling_properties_model() throws {
        // Arrange
        let defaultStyle = StylingPropertiesModel(container: ContainerStylingProperties(justifyContent: .center,
                                                                                        alignItems: .center,
                                                                                        shadow: Shadow(offsetX: 0,
                                                                                                       offsetY: 0,
                                                                                                       blurRadius: 0,
                                                                                                       spreadRadius: 0,
                                                                                                       color: ThemeColor(light: "#111111",
                                                                                                                         dark: nil)),
                                                                                        overflow: .visible, gap: nil, blur: 0),
                                                  background: BackgroundStylingProperties(backgroundColor:
                                                                                            ThemeColor(light: "#111111",
                                                                                                       dark: nil),
                                                                                          backgroundImage: nil),
                                                  dimension: DimensionStylingProperties(minWidth: 0,
                                                                                        maxWidth: 0,
                                                                                        width: .fit(.wrapContent),
                                                                                        minHeight: 0,
                                                                                        maxHeight: 0,
                                                                                        height: .fixed(10), rotateZ: nil),
                                                  flexChild: FlexChildStylingProperties(weight: 0,
                                                                                        order: 0,
                                                                                        alignSelf: .center),
                                                  spacing: SpacingStylingProperties(padding: "0",
                                                                                    margin: "0",
                                                                                    offset: nil),
                                                  border: BorderStylingProperties(borderRadius: 10,
                                                                                  borderColor: ThemeColor(light: "#111111",
                                                                                                          dark: nil),
                                                                                  borderWidth: "2",
                                                                                  borderStyle: .solid))
        
        let pressed = StylingPropertiesModel(container: nil,
                                             background: BackgroundStylingProperties(backgroundColor:
                                                                                        ThemeColor(light: "#111112", dark: nil),
                                                                                     backgroundImage: nil),
                                             dimension: nil,
                                             flexChild: FlexChildStylingProperties(weight: nil,
                                                                                   order: 1,
                                                                                   alignSelf: nil),
                                             spacing: nil,
                                             border: nil)
        
        let expectedStyle = StylingPropertiesModel(container: ContainerStylingProperties(justifyContent: .center,
                                                                                         alignItems: .center,
                                                                                         shadow: Shadow(offsetX: 0,
                                                                                                        offsetY: 0,
                                                                                                        blurRadius: 0,
                                                                                                        spreadRadius: 0,
                                                                                                        color: ThemeColor(light: "#111111",
                                                                                                                          dark: nil)),
                                                                                         overflow: .visible, gap: nil, blur: 0),
                                                   background: BackgroundStylingProperties(backgroundColor:
                                                                                            ThemeColor(light: "#111112",
                                                                                                       dark: nil),
                                                                                           backgroundImage: nil),
                                                   dimension: DimensionStylingProperties(minWidth: 0,
                                                                                         maxWidth: 0,
                                                                                         width: .fit(.wrapContent),
                                                                                         minHeight: 0,
                                                                                         maxHeight: 0,
                                                                                         height: .fixed(10), rotateZ: nil),
                                                   flexChild: FlexChildStylingProperties(weight: 0,
                                                                                         order: 1,
                                                                                         alignSelf: .center),
                                                   spacing: SpacingStylingProperties(padding: "0",
                                                                                     margin: "0",
                                                                                     offset: nil),
                                                   border: BorderStylingProperties(borderRadius: 10,
                                                                                   borderColor: ThemeColor(light: "#111111",
                                                                                                           dark: nil),
                                                                                   borderWidth: "2",
                                                                                   borderStyle: .solid))
        
        // ACT
        let transformedStyle = try StyleTransformer.getUpdatedStyle(defaultStyle, newStyle: pressed)
        
        // Assert
        XCTAssertEqual(transformedStyle.container, expectedStyle.container)
        XCTAssertEqual(transformedStyle.background, expectedStyle.background)
        XCTAssertEqual(transformedStyle.dimension, expectedStyle.dimension)
        XCTAssertEqual(transformedStyle.flexChild, expectedStyle.flexChild)
        XCTAssertEqual(transformedStyle.spacing, expectedStyle.spacing)
        XCTAssertEqual(transformedStyle.border, expectedStyle.border)
    }
    
    func test_get_updated_style_basic_text() throws {
        // Arrange
        let defaultStyle = BasicTextStyle(dimension: DimensionStylingProperties(minWidth: 10,
                                                                                maxWidth: 100,
                                                                                width: nil,
                                                                                minHeight: 10,
                                                                                maxHeight: 110,
                                                                                height: nil,
                                                                                rotateZ: nil),
                                          flexChild: nil,
                                          spacing: SpacingStylingProperties(padding: "10",
                                                                            margin: nil,
                                                                            offset: nil),
                                          background: nil,
                                          text: TextStylingProperties(textColor: ThemeColor(light: "#123123", dark: nil),
                                                                      fontSize: 12,
                                                                      fontFamily: "Arial",
                                                                      fontWeight: .w400,
                                                                      lineHeight: 10,
                                                                      horizontalTextAlign: .center,
                                                                      baselineTextAlign: .none,
                                                                      fontStyle: .normal,
                                                                      textTransform: .lowercase,
                                                                      letterSpacing: 10,
                                                                      textDecoration: nil,
                                                                      lineLimit: 0))
        
        let pressed = BasicTextStyle(dimension: nil,
                                     flexChild: nil,
                                     spacing: nil,
                                     background: nil,
                                     text: TextStylingProperties(textColor: ThemeColor(light: "#000000", dark: nil),
                                                                 fontSize: 11,
                                                                 fontFamily: nil,
                                                                 fontWeight: nil,
                                                                 lineHeight: nil,
                                                                 horizontalTextAlign: nil,
                                                                 baselineTextAlign: nil,
                                                                 fontStyle: nil,
                                                                 textTransform: nil,
                                                                 letterSpacing: nil,
                                                                 textDecoration: nil,
                                                                 lineLimit: nil))
        
        let expectedStyle = BasicTextStyle(dimension: DimensionStylingProperties(minWidth: 10,
                                                                                 maxWidth: 100,
                                                                                 width: nil,
                                                                                 minHeight: 10,
                                                                                 maxHeight: 110,
                                                                                 height: nil, 
                                                                                 rotateZ: nil),
                                           flexChild: nil,
                                           spacing: SpacingStylingProperties(padding: "10",
                                                                             margin: nil,
                                                                             offset: nil),
                                           background: nil,
                                           text: TextStylingProperties(textColor: ThemeColor(light: "#000000", dark: nil),
                                                                       fontSize: 11,
                                                                       fontFamily: "Arial",
                                                                       fontWeight: .w400,
                                                                       lineHeight: 10,
                                                                       horizontalTextAlign: .center,
                                                                       baselineTextAlign: .none,
                                                                       fontStyle: .normal,
                                                                       textTransform: .lowercase,
                                                                       letterSpacing: 10,
                                                                       textDecoration: nil,
                                                                       lineLimit: 0))
        
        // ACT
        let transformedStyle = try StyleTransformer.getUpdatedStyle(defaultStyle, newStyle: pressed)
        
        // Assert
        XCTAssertEqual(transformedStyle.background, expectedStyle.background)
        XCTAssertEqual(transformedStyle.dimension, expectedStyle.dimension)
        XCTAssertEqual(transformedStyle.flexChild, expectedStyle.flexChild)
        XCTAssertEqual(transformedStyle.spacing, expectedStyle.spacing)
        XCTAssertEqual(transformedStyle.text, expectedStyle.text)
    }
    
    func test_get_updated_style_data_image() throws {
        // Arrange
        let defaultStyle = DataImageStyles(background: nil,
                                           border: nil,
                                           dimension: DimensionStylingProperties(minWidth: nil,
                                                                                 maxWidth: nil,
                                                                                 width: .fit(.wrapContent),
                                                                                 minHeight: nil,
                                                                                 maxHeight: nil,
                                                                                 height: nil, 
                                                                                 rotateZ: nil),
                                           flexChild: FlexChildStylingProperties(weight: 0, order: 0, alignSelf: nil),
                                           spacing: nil)
        
        let pressed = DataImageStyles(background: BackgroundStylingProperties(backgroundColor: ThemeColor(light: "#000000",
                                                                                                          dark: nil),
                                                                              backgroundImage: nil),
                                      border: nil, dimension: nil, flexChild: nil, spacing: nil)
        
        let expectedStyle = DataImageStyles(background: BackgroundStylingProperties(backgroundColor: ThemeColor(light: "#000000",
                                                                                                                dark: nil),
                                                                                    backgroundImage: nil),
                                            border: nil,
                                            dimension: DimensionStylingProperties(minWidth: nil,
                                                                                  maxWidth: nil,
                                                                                  width: .fit(.wrapContent),
                                                                                  minHeight: nil,
                                                                                  maxHeight: nil,
                                                                                  height: nil,
                                                                                  rotateZ: nil),
                                            flexChild: FlexChildStylingProperties(weight: 0, order: 0, alignSelf: nil),
                                            spacing: nil)
        
        // ACT
        let transformedStyle = try StyleTransformer.getUpdatedStyle(defaultStyle, newStyle: pressed)
        
        // Assert
        XCTAssertEqual(transformedStyle.background, expectedStyle.background)
        XCTAssertEqual(transformedStyle.dimension, expectedStyle.dimension)
        XCTAssertEqual(transformedStyle.flexChild, expectedStyle.flexChild)
        XCTAssertEqual(transformedStyle.spacing, expectedStyle.spacing)
        XCTAssertEqual(transformedStyle.border, expectedStyle.border)
    }
    
    func test_get_updated_style_static_image() throws {
        // Arrange
        let defaultStyle = StaticImageStyles(background: nil,
                                             border: nil,
                                             dimension: DimensionStylingProperties(minWidth: nil,
                                                                                   maxWidth: nil,
                                                                                   width: .fit(.wrapContent),
                                                                                   minHeight: nil,
                                                                                   maxHeight: nil,
                                                                                   height: nil, 
                                                                                 rotateZ: nil),
                                             flexChild: FlexChildStylingProperties(weight: 0, order: 0, alignSelf: nil),
                                             spacing: nil)
        
        let pressed = StaticImageStyles(background: BackgroundStylingProperties(backgroundColor: ThemeColor(light: "#000000",
                                                                                                            dark: nil),
                                                                                backgroundImage: nil),
                                        border: nil, dimension: nil, flexChild: nil, spacing: nil)
        
        let expectedStyle =
            StaticImageStyles(background: BackgroundStylingProperties(backgroundColor: ThemeColor(light: "#000000",
                                                                                                  dark: nil),
                                                                      backgroundImage: nil),
                              border: nil,
                              dimension: DimensionStylingProperties(minWidth: nil,
                                                                    maxWidth: nil,
                                                                    width: .fit(.wrapContent),
                                                                    minHeight: nil,
                                                                    maxHeight: nil,
                                                                    height: nil, 
                                                                                  rotateZ: nil),
                              flexChild: FlexChildStylingProperties(weight: 0, order: 0, alignSelf: nil),
                              spacing: nil)
        
        // ACT
        let transformedStyle = try StyleTransformer.updatedStyle(defaultStyle, newStyle: pressed)
        
        // Assert
        XCTAssertEqual(transformedStyle?.background, expectedStyle.background)
        XCTAssertEqual(transformedStyle?.dimension, expectedStyle.dimension)
        XCTAssertEqual(transformedStyle?.flexChild, expectedStyle.flexChild)
        XCTAssertEqual(transformedStyle?.spacing, expectedStyle.spacing)
        XCTAssertEqual(transformedStyle?.border, expectedStyle.border)
    }
    
    func test_get_updated_style_static_image_with_breakpoints() throws {
        // Arrange
        let defaultStyle = StaticImageStyles(background: nil,
                                             border: nil,
                                             dimension: DimensionStylingProperties(minWidth: nil,
                                                                                   maxWidth: nil,
                                                                                   width: .fit(.wrapContent),
                                                                                   minHeight: nil,
                                                                                   maxHeight: nil,
                                                                                   height: nil, 
                                                                                 rotateZ: nil),
                                             flexChild: FlexChildStylingProperties(weight: 0, order: 0, alignSelf: nil),
                                             spacing: nil)
        
        let pressed = StaticImageStyles(background: BackgroundStylingProperties(backgroundColor: ThemeColor(light: "#000000",
                                                                                                            dark: nil),
                                                                                backgroundImage: nil),
                                        border: nil, dimension: nil, flexChild: nil, spacing: nil)
        
        let expectedStyle =
            StaticImageStyles(background: BackgroundStylingProperties(backgroundColor: ThemeColor(light: "#000000",
                                                                                                  dark: nil),
                                                                      backgroundImage: nil),
                              border: nil,
                              dimension: DimensionStylingProperties(minWidth: nil,
                                                                    maxWidth: nil,
                                                                    width: .fit(.wrapContent),
                                                                    minHeight: nil,
                                                                    maxHeight: nil,
                                                                    height: nil, 
                                                                                  rotateZ: nil),
                              flexChild: FlexChildStylingProperties(weight: 0, order: 0, alignSelf: nil),
                              spacing: nil)
        let styles = [BasicStateStylingBlock<StaticImageStyles>(default: defaultStyle,
                                                                pressed: nil,
                                                                hovered: nil,
                                                                focussed: nil,
                                                                disabled: nil),
                      BasicStateStylingBlock<StaticImageStyles>(default: defaultStyle,
                                                                pressed: pressed,
                                                                hovered: nil,
                                                                focussed: nil,
                                                                disabled: nil)]
        // ACT
        let transformedStyle = try StyleTransformer.updatedStyles(styles)
        
        // Assert pressed Style
        // No changes on default style
        XCTAssertEqual(transformedStyle.first?.default.background, defaultStyle.background)
        XCTAssertEqual(transformedStyle.first?.default.dimension, defaultStyle.dimension)
        XCTAssertEqual(transformedStyle.first?.default.flexChild, defaultStyle.flexChild)
        XCTAssertEqual(transformedStyle.first?.default.spacing, defaultStyle.spacing)
        XCTAssertEqual(transformedStyle.first?.default.border, defaultStyle.border)
        // The pressed styles should be the same as default
        XCTAssertEqual(transformedStyle.first?.pressed?.background, defaultStyle.background)
        XCTAssertEqual(transformedStyle.first?.pressed?.dimension, defaultStyle.dimension)
        XCTAssertEqual(transformedStyle.first?.pressed?.flexChild, defaultStyle.flexChild)
        XCTAssertEqual(transformedStyle.first?.pressed?.spacing, defaultStyle.spacing)
        XCTAssertEqual(transformedStyle.first?.pressed?.border, defaultStyle.border)
        
        // Check the second bereakpoint
        XCTAssertEqual(transformedStyle[1].default.background, defaultStyle.background)
        XCTAssertEqual(transformedStyle[1].default.dimension, defaultStyle.dimension)
        XCTAssertEqual(transformedStyle[1].default.flexChild, defaultStyle.flexChild)
        XCTAssertEqual(transformedStyle[1].default.spacing, defaultStyle.spacing)
        XCTAssertEqual(transformedStyle[1].default.border, defaultStyle.border)
        // Check the pressed style on the second bereakpoint 
        XCTAssertEqual(transformedStyle[1].pressed?.background, expectedStyle.background)
        XCTAssertEqual(transformedStyle[1].pressed?.dimension, expectedStyle.dimension)
        XCTAssertEqual(transformedStyle[1].pressed?.flexChild, expectedStyle.flexChild)
        XCTAssertEqual(transformedStyle[1].pressed?.spacing, expectedStyle.spacing)
        XCTAssertEqual(transformedStyle[1].pressed?.border, expectedStyle.border)
    }
    
    func test_get_updated_style_progress_indicator() throws {
        // Arrange
        let defaultStyle = IndicatorStyles(container: nil,
                                           background: nil,
                                           border: nil,
                                           dimension: nil,
                                           flexChild: nil,
                                           spacing: SpacingStylingProperties(padding: "0",
                                                                             margin: nil,
                                                                             offset: nil),
                                           text: nil)
        
        let activeStyle = IndicatorStyles(container: nil,
                                          background: nil,
                                          border: nil,
                                          dimension: nil,
                                          flexChild: nil,
                                          spacing: SpacingStylingProperties(padding: nil,
                                                                            margin: "1",
                                                                            offset: nil),
                                          text: nil)
        
        let indicator = [BasicStateStylingBlock(default: defaultStyle, pressed: nil, hovered: nil, focussed: nil, disabled: nil)]
        let active = [BasicStateStylingBlock(default: activeStyle, pressed: nil, hovered: nil, focussed: nil, disabled: nil)]
        
        // ACT
        let transformedStyle = try StyleTransformer.updatedIndicatorStyles(indicator, newStyles: active)
        
        // Assert
        XCTAssertEqual(transformedStyle.first?.default.spacing?.margin, "1")
        XCTAssertEqual(transformedStyle.first?.default.spacing?.padding, "0")
        
    }
    
    func test_get_updated_style_progress_indicator_with_breakpoints() throws {
        // Arrange
        let defaultStyle1 = IndicatorStyles(container: nil,
                                            background: nil,
                                            border: nil,
                                            dimension: nil,
                                            flexChild: nil,
                                            spacing: SpacingStylingProperties(padding: "0",
                                                                              margin: nil,
                                                                              offset: nil),
                                            text: nil)
        
        let backgroundColor = ThemeColor(light: "#000000", dark: nil)
        let pressedStyle1 = IndicatorStyles(container: nil,
                                            background: BackgroundStylingProperties(backgroundColor: backgroundColor,
                                                                                    backgroundImage: nil),
                                            border: nil,
                                            dimension: nil,
                                            flexChild: nil,
                                            spacing: nil,
                                            text: nil)
        let defaultStyle2 = IndicatorStyles(container: nil,
                                            background: nil,
                                            border: nil,
                                            dimension: nil,
                                            flexChild: nil,
                                            spacing: nil,
                                            text: nil)
       
        let activeStyle1 = IndicatorStyles(container: nil,
                                           background: nil,
                                           border: nil,
                                           dimension: nil,
                                           flexChild: nil,
                                           spacing: SpacingStylingProperties(padding: nil,
                                                                             margin: "1",
                                                                             offset: nil),
                                           text: nil)
        
        let indicator =
            [BasicStateStylingBlock(default: defaultStyle1, pressed: pressedStyle1, hovered: nil, focussed: nil, disabled: nil),
             BasicStateStylingBlock(default: defaultStyle2, pressed: nil, hovered: nil, focussed: nil, disabled: nil)]
        let active = [BasicStateStylingBlock(default: activeStyle1, pressed: nil, hovered: nil, focussed: nil, disabled: nil)]
        
        // ACT
        let transformedStyle = try StyleTransformer.updatedIndicatorStyles(indicator, newStyles: active)
        
        // Assert
        // Check the second breakpoint
        XCTAssertEqual(transformedStyle[1].pressed?.spacing?.margin, "1")
        XCTAssertEqual(transformedStyle[1].pressed?.spacing?.padding, "0")
        XCTAssertEqual(transformedStyle[1].pressed?.background?.backgroundColor, backgroundColor)
        
    }
    
    func test_get_updated_style_row_with_breakpoints() throws {
        // Arrange
        let defaultStyle1 = RowStyle(container: nil,
                                     background: nil,
                                     border: nil,
                                     dimension: nil,
                                     flexChild: FlexChildStylingProperties(weight: 0, order: 0, alignSelf: nil),
                                     spacing: nil)
                
        let defaultStyle2 = RowStyle(container: nil,
                                     background: nil,
                                     border: nil,
                                     dimension: nil,
                                     flexChild: FlexChildStylingProperties(weight: 5, order: 5, alignSelf: nil),
                                     spacing: nil)
        
        let hoveredStyle1 = RowStyle(container: nil,
                                     background: nil,
                                     border: nil,
                                     dimension: nil,
                                     flexChild: FlexChildStylingProperties(weight: 10, order: 10, alignSelf: nil),
                                     spacing: nil)
        
        let styles =
            [BasicStateStylingBlock(default: defaultStyle1, pressed: nil, hovered: hoveredStyle1, focussed: nil, disabled: nil),
             BasicStateStylingBlock(default: defaultStyle2, pressed: nil, hovered: nil, focussed: nil, disabled: nil)]

        // ACT
        let transformedStyle = try StyleTransformer.updatedStyles(styles)
        
        // Assert
        // Check the second breakpoint
        XCTAssertEqual(transformedStyle[1].default.flexChild?.weight, 5)
        XCTAssertEqual(transformedStyle[1].default.flexChild?.order, 5)
        // check the second breakpoint hovered
        XCTAssertEqual(transformedStyle[1].hovered?.flexChild?.weight, 10)
        XCTAssertEqual(transformedStyle[1].hovered?.flexChild?.order, 10)

    }
    
    func test_get_updated_style_empty_default_creative_response() throws {
        // Arrange
        let defaultStyle = CreativeResponseStyles(container: nil,
                                                  background: nil,
                                                  border: nil,
                                                  dimension: nil,
                                                  flexChild: nil,
                                                  spacing: nil)
        
        let pressed = CreativeResponseStyles(container: nil,
                                             background: nil,
                                             border: BorderStylingProperties(borderRadius: 12,
                                                                             borderColor: ThemeColor(light: "#FF0000",
                                                                                                     dark: "#FF0000"),
                                                                             borderWidth: "2",
                                                                             borderStyle: nil),
                                             dimension: nil,
                                             flexChild: nil,
                                             spacing: nil)
        
        let expectedStyle = CreativeResponseStyles(container: nil,
                                                   background: nil,
                                                   border: BorderStylingProperties(borderRadius: 12,
                                                                                   borderColor: ThemeColor(light: "#FF0000",
                                                                                                           dark: "#FF0000"),
                                                                                   borderWidth: "2",
                                                                                   borderStyle: nil),
                                                   dimension: nil,
                                                   flexChild: nil,
                                                   spacing: nil)
        
        // ACT
        let transformedStyle = try StyleTransformer.getUpdatedStyle(defaultStyle, newStyle: pressed)
        
        // Assert
        XCTAssertEqual(transformedStyle.container, expectedStyle.container)
        XCTAssertEqual(transformedStyle.background, expectedStyle.background)
        XCTAssertEqual(transformedStyle.dimension, expectedStyle.dimension)
        XCTAssertEqual(transformedStyle.flexChild, expectedStyle.flexChild)
        XCTAssertEqual(transformedStyle.spacing, expectedStyle.spacing)
        XCTAssertEqual(transformedStyle.border, expectedStyle.border)
    }
    
    func test_invalid_empty_background_color_throws_error() throws {
        // Arrange
        let defaultStyle = StylingPropertiesModel(container: ContainerStylingProperties(justifyContent: .center,
                                                                                        alignItems: .center,
                                                                                        shadow: Shadow(offsetX: 0,
                                                                                                       offsetY: 0,
                                                                                                       blurRadius: 0,
                                                                                                       spreadRadius: 0,
                                                                                                       color: ThemeColor(light: "#333333",
                                                                                                                         dark: nil)),
                                                                                        overflow: .visible, gap: nil,
                                                                                        blur: nil),
                                                  background: BackgroundStylingProperties(backgroundColor:
                                                                                            ThemeColor(light: "", dark: nil),
                                                                                          backgroundImage: nil),
                                                  dimension: DimensionStylingProperties(minWidth: 0,
                                                                                        maxWidth: 0,
                                                                                        width: .fit(.wrapContent),
                                                                                        minHeight: 0,
                                                                                        maxHeight: 0,
                                                                                        height: .fixed(10), 
                                                                                        rotateZ: nil),
                                                  flexChild: FlexChildStylingProperties(weight: 0,
                                                                                        order: 0,
                                                                                        alignSelf: .center),
                                                  spacing: SpacingStylingProperties(padding: "0",
                                                                                    margin: "0",
                                                                                    offset: nil),
                                                  border: BorderStylingProperties(borderRadius: 10,
                                                                                  borderColor: ThemeColor(light: "#111111",
                                                                                                          dark: nil),
                                                                                  borderWidth: "2",
                                                                                  borderStyle: .solid))
        
        // ACT
        // Assert
        XCTAssertThrowsError(try StyleTransformer.getUpdatedStyle(defaultStyle, newStyle: nil))
    }
    
    func test_invalid_shadow_color_throws_error() throws {
        // Arrange
        let defaultStyle = StylingPropertiesModel(container: ContainerStylingProperties(justifyContent: .center,
                                                                                        alignItems: .center,
                                                                                        shadow: Shadow(offsetX: 0,
                                                                                                       offsetY: 0,
                                                                                                       blurRadius: 0,
                                                                                                       spreadRadius: 0,
                                                                                                       color: ThemeColor(light: "color",
                                                                                                                         dark: nil)),
                                                                                        overflow: .visible, gap: nil, blur: nil),
                                                  background: nil,
                                                  dimension: DimensionStylingProperties(minWidth: 0,
                                                                                        maxWidth: 0,
                                                                                        width: .fit(.wrapContent),
                                                                                        minHeight: 0,
                                                                                        maxHeight: 0,
                                                                                        height: .fixed(10), rotateZ: nil),
                                                  flexChild: FlexChildStylingProperties(weight: 0,
                                                                                        order: 0,
                                                                                        alignSelf: .center),
                                                  spacing: SpacingStylingProperties(padding: "0",
                                                                                    margin: "0",
                                                                                    offset: nil),
                                                  border: BorderStylingProperties(borderRadius: 10,
                                                                                  borderColor: ThemeColor(light: "#111111",
                                                                                                          dark: nil),
                                                                                  borderWidth: "2",
                                                                                  borderStyle: .solid))
        
        // ACT
        // Assert
        XCTAssertThrowsError(try StyleTransformer.getUpdatedStyle(defaultStyle, newStyle: nil))
    }

    func test_get_updated_carousel_indicator_styles() throws {
        // Arrange
        let defaultStyle = DataImageCarouselIndicatorStyles(container: nil,
                                                            background: nil,
                                                            border: nil,
                                                            dimension: nil,
                                                            flexChild: nil,
                                                            spacing: SpacingStylingProperties(padding: "0",
                                                                                              margin: nil,
                                                                                              offset: nil))

        let activeStyle = DataImageCarouselIndicatorStyles(container: nil,
                                                           background: nil,
                                                           border: nil,
                                                           dimension: nil,
                                                           flexChild: nil,
                                                           spacing: SpacingStylingProperties(padding: nil,
                                                                                             margin: "1",
                                                                                             offset: nil))

        let indicator = [BasicStateStylingBlock(default: defaultStyle, pressed: nil, hovered: nil, focussed: nil, disabled: nil)]
        let active = [BasicStateStylingBlock(default: activeStyle, pressed: nil, hovered: nil, focussed: nil, disabled: nil)]

        // ACT
        let transformedStyle = try StyleTransformer.updatedIndicatorStyles(indicator, newStyles: active)

        // Assert
        XCTAssertEqual(transformedStyle.first?.default.spacing?.margin, "1")
        XCTAssertEqual(transformedStyle.first?.default.spacing?.padding, "0")
    }

    func test_get_updated_carousel_indicator_styles_with_breakpoints() throws {
        // Arrange
        let defaultStyle1 = DataImageCarouselIndicatorStyles(container: nil,
                                                             background: nil,
                                                             border: nil,
                                                             dimension: nil,
                                                             flexChild: nil,
                                                             spacing: SpacingStylingProperties(padding: "0",
                                                                                               margin: nil,
                                                                                               offset: nil))

        let backgroundColor = ThemeColor(light: "#000000", dark: nil)
        let pressedStyle1 = DataImageCarouselIndicatorStyles(container: nil,
                                                             background: BackgroundStylingProperties(backgroundColor: backgroundColor,
                                                                                                     backgroundImage: nil),
                                                             border: nil,
                                                             dimension: nil,
                                                             flexChild: nil,
                                                             spacing: nil)

        let defaultStyle2 = DataImageCarouselIndicatorStyles(container: nil,
                                                             background: nil,
                                                             border: nil,
                                                             dimension: nil,
                                                             flexChild: nil,
                                                             spacing: nil)

        let activeStyle1 = DataImageCarouselIndicatorStyles(container: nil,
                                                            background: nil,
                                                            border: nil,
                                                            dimension: nil,
                                                            flexChild: nil,
                                                            spacing: SpacingStylingProperties(padding: nil,
                                                                                              margin: "1",
                                                                                              offset: nil))

        let indicator =
            [BasicStateStylingBlock(default: defaultStyle1, pressed: pressedStyle1, hovered: nil, focussed: nil, disabled: nil),
             BasicStateStylingBlock(default: defaultStyle2, pressed: nil, hovered: nil, focussed: nil, disabled: nil)]
        let active = [BasicStateStylingBlock(default: activeStyle1, pressed: nil, hovered: nil, focussed: nil, disabled: nil)]

        // ACT
        let transformedStyle = try StyleTransformer.updatedIndicatorStyles(indicator, newStyles: active)

        // Assert
        // Check the second breakpoint
        XCTAssertEqual(transformedStyle[1].pressed?.spacing?.margin, "1")
        XCTAssertEqual(transformedStyle[1].pressed?.spacing?.padding, "0")
        XCTAssertEqual(transformedStyle[1].pressed?.background?.backgroundColor, backgroundColor)
    }
}
