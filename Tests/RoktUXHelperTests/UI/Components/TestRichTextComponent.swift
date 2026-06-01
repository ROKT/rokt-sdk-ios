import XCTest
import SwiftUI
import ViewInspector
@testable import RoktUXHelper
import DcuiSchema
import SnapshotTesting

@available(iOS 15.0, *)
final class TestRichTextComponent: XCTestCase {

    func test_rich_text() throws {
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.richText(try get_model()))
        
        let text = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(RichTextComponent.self)
            .actualView()
            .inspect()
            .text()
        
        // test custom modifier class
        let paddingModifier = try text.modifier(PaddingModifier.self)
        XCTAssertEqual(try paddingModifier.actualView().padding, FrameAlignmentProperty(top: 1, right: 0, bottom: 1, left: 8))
        
        // test the effect of custom modifier
        let padding = try text.padding()
        XCTAssertEqual(padding, EdgeInsets(top: 1.0, leading: 8.0, bottom: 17.0, trailing: 0.0))
        
        let model = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(RichTextComponent.self)
            .actualView()
            .model
        let nsAttrString = model.attributedString
        
        XCTAssertEqual(nsAttrString.string, "ORDER Number: Uk171359906")
        
        // space-agnostic colour comparison
        let foregroundColor = nsAttrString.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(foregroundColor?.isEqualIgnoringSpaceContext(UIColor(hexString: "#AABBCC")), true)
        
        let font = nsAttrString.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        
        XCTAssertEqual(font?.fontDescriptor.symbolicTraits.contains(.traitBold), true)
        XCTAssertEqual(font?.fontDescriptor.symbolicTraits.contains(.traitItalic), true)
        
        let underlineRange = NSRange(location: 0, length: 5)
        let underlineText = nsAttrString.attributedSubstring(from: underlineRange)
        
        underlineText.enumerateAttributes(in: underlineRange, options: []) { (dict, _, _) in
            XCTAssertTrue(dict.keys.contains(.underlineStyle))
        }
        
        let strikeThroughRange = NSRange(location: 6, length: 6)
        let strikeThroughText = nsAttrString.attributedSubstring(from: strikeThroughRange)
        let strikeThroughTextRange = NSRange(location: 0, length: 6)
        
        strikeThroughText.enumerateAttributes(in: strikeThroughTextRange, options: []) { (dict, _, _) in
            XCTAssertTrue(dict.keys.contains(.strikethroughStyle))
        }
        
        // raw richtext
        let rawText = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(RichTextComponent.self)
            .actualView()
        XCTAssertNil(rawText.linkStyle)
        
        XCTAssertEqual(rawText.horizontalAlignment, .start)

        XCTAssertNil(rawText.lineLimit)
        
        XCTAssertEqual(rawText.lineHeightPadding, 0)
        XCTAssertEqual(rawText.lineHeight, 0)
    }
    
    func test_rich_text_with_state() throws {
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.richText(try get_state_model()))
        
        let text = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(RichTextComponent.self)
            .actualView()
            .inspect()
            .text()
        
        // test custom modifier class
        let paddingModifier = try text.modifier(PaddingModifier.self)
        XCTAssertEqual(try paddingModifier.actualView().padding, FrameAlignmentProperty(top: 1, right: 0, bottom: 1, left: 8))
        
        // test the effect of custom modifier
        let padding = try text.padding()
        XCTAssertEqual(padding, EdgeInsets(top: 1.0, leading: 8.0, bottom: 17.0, trailing: 0.0))
        
        let model = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(RichTextComponent.self)
            .actualView()
            .model
        let nsAttrString = model.attributedString
        //before state replacement
        XCTAssertEqual(nsAttrString.string, "%^STATE.IndicatorPosition^% ORDER Number:")
        
        // space-agnostic colour comparison
        let foregroundColor = nsAttrString.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(foregroundColor?.isEqualIgnoringSpaceContext(UIColor(hexString: "#AABBCC")), true)
        
        let font = nsAttrString.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        
        XCTAssertEqual(font?.fontDescriptor.symbolicTraits.contains(.traitBold), false)
        XCTAssertEqual(font?.fontDescriptor.symbolicTraits.contains(.traitItalic), false)

        // check min/max width/height
        let flexFrame = try text.flexFrame()
        XCTAssertEqual(flexFrame.minWidth, 10)
        XCTAssertEqual(flexFrame.maxWidth, 100)
        XCTAssertEqual(flexFrame.minHeight, 15)
        XCTAssertEqual(flexFrame.maxHeight, 150)
        
        // raw richtext
        let rawText = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(RichTextComponent.self)
            .actualView()
        XCTAssertNil(rawText.linkStyle)
        
        XCTAssertEqual(rawText.horizontalAlignment, .start)
        // after state replacement
        XCTAssertEqual(rawText.model.stateReplacedAttributedString.string, "1 ORDER Number:")
        let colors = rawText.model.stateReplacedAttributedString.attribute(
            .foregroundColor,
            at: 0,
            effectiveRange: nil
        ) as? UIColor
        XCTAssertEqual(colors?.isEqualIgnoringSpaceContext(UIColor(hexString: "#AABBCC")), true)
        XCTAssertNil(rawText.lineLimit)
        
        XCTAssertEqual(rawText.lineHeightPadding, 0)
        XCTAssertEqual(rawText.lineHeight, 0)
    }
    
    func test_rich_text_with_app_config() throws {
        if let model = try get_dark_config_model() {
            
            let view = TestPlaceHolder(layout: model)
            
            let text = try view.inspect()
                .view(TestPlaceHolder.self)
                .view(EmbeddedComponent.self)
                .vStack()[0]
                .view(LayoutSchemaComponent.self)
                .view(RichTextComponent.self)
                .actualView()
                .inspect()
                .text()
            
            // test custom modifier class
            let paddingModifier = try text.modifier(PaddingModifier.self)
            XCTAssertEqual(
                try paddingModifier.actualView().padding,
                FrameAlignmentProperty(top: 1, right: 0, bottom: 1, left: 8)
            )
            
            // test the effect of custom modifier
            let padding = try text.padding()
            XCTAssertEqual(padding, EdgeInsets(top: 1.0, leading: 8.0, bottom: 17.0, trailing: 0.0))
            
            let model = try view.inspect()
                .view(TestPlaceHolder.self)
                .view(EmbeddedComponent.self)
                .vStack()[0]
                .view(LayoutSchemaComponent.self)
                .view(RichTextComponent.self)
                .actualView()
                .model
            let nsAttrString = model.attributedString

            XCTAssertEqual(nsAttrString.string, "ORDER Number: Uk171359906")
            
            // Test color mode to be dark
            let foregroundColor = nsAttrString.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
            XCTAssertEqual(foregroundColor?.isEqualIgnoringSpaceContext(UIColor(hexString: "#000000")), true)
        }
    }
    
    // MARK: - Snapshots

    func testSnapshot() throws {
        assertRichTextSnapshot(try get_model(), width: 350, height: 350)
    }

    func testSnapshot_nilDefaultStyle() {
        let model = RichTextViewModel(
            value: "<b>Bold</b> and <i>italic</i> with <font color=#0066CC><a href='https://rokt.com'>a link</a></font>",
            defaultStyle: nil,
            openLinks: nil,
            layoutState: LayoutState(),
            eventService: nil
        )
        assertRichTextSnapshot(model)
    }

    func testSnapshot_nilTextStyle() {
        let model = RichTextViewModel(
            value: "<b>Bold</b> and <i>italic</i> text",
            defaultStyle: [RichTextStyle(dimension: nil, flexChild: nil, spacing: nil, background: nil, text: nil)],
            openLinks: nil,
            layoutState: LayoutState(),
            eventService: nil
        )
        assertRichTextSnapshot(model)
    }

    /// Multiple <p> blocks separated by paragraph spacing.
    func testSnapshot_paragraphs() {
        let model = RichTextViewModel(
            value: "<p>First paragraph with some text.</p><p>Second paragraph follows with vertical spacing.</p><p>Third paragraph.</p>",
            defaultStyle: nil,
            openLinks: nil,
            layoutState: LayoutState(),
            eventService: nil
        )
        assertRichTextSnapshot(model, height: 250)
    }

    /// Unordered list — bullet markers with hanging indent on wrapped lines.
    func testSnapshot_unorderedList() {
        let model = RichTextViewModel(
            value: "<ul><li>First item</li><li>Second item that is long enough to wrap onto a second line and verify the hanging indent</li><li>Third</li></ul>",
            defaultStyle: nil,
            openLinks: nil,
            layoutState: LayoutState(),
            eventService: nil
        )
        assertRichTextSnapshot(model, height: 250)
    }

    /// Ordered list — sequential numbering with hanging indent.
    func testSnapshot_orderedList() {
        let model = RichTextViewModel(
            value: "<ol><li>First</li><li>Second item with longer text that should wrap and align with the start of this text not the number</li><li>Third</li></ol>",
            defaultStyle: nil,
            openLinks: nil,
            layoutState: LayoutState(),
            eventService: nil
        )
        assertRichTextSnapshot(model, height: 250)
    }

    /// WYSIWYG pattern <li><p>...</p></li> — marker and text on the same line.
    func testSnapshot_listItemWithParagraph() {
        let model = RichTextViewModel(
            value: "<ul><li><p>WYSIWYG paragraph inside list item</p></li><li><p>Second paragraph item</p></li></ul>",
            defaultStyle: nil,
            openLinks: nil,
            layoutState: LayoutState(),
            eventService: nil
        )
        assertRichTextSnapshot(model)
    }

    /// List marker inherits surrounding font color (<font color>).
    func testSnapshot_listMarkerInheritsColor() {
        let model = RichTextViewModel(
            value: "<font color=#CC0066><ul><li>Marker and text both pink</li><li>Same on this line</li></ul></font>",
            defaultStyle: nil,
            openLinks: nil,
            layoutState: LayoutState(),
            eventService: nil
        )
        assertRichTextSnapshot(model)
    }

    // MARK: - Block spacing regression snapshots

    //
    // These tests pin the inter-block spacing produced when a caller provides
    // a non-trivial `lineHeight` on the RichText style — the codepath fixed
    // by the `blockSpacerLineHeightRatio` scaling in `LightweightHTMLParser`.
    // Without the scaling, the invisible spacer between blocks renders at
    // the full lineHeight font size, producing a near-blank-line gap.

    /// Three `<p>` blocks rendered with a 20pt lineHeight.
    func testSnapshot_paragraphs_withLineHeight() {
        let model = RichTextViewModel(
            value: "<p>Alpha paragraph with text long enough to wrap onto a second line.</p><p>Bravo paragraph.</p><p>Charlie paragraph.</p>",
            defaultStyle: [richTextStyle(lineHeight: 20)],
            openLinks: nil,
            layoutState: LayoutState(),
            eventService: nil
        )
        assertRichTextSnapshot(model, height: 300)
    }

    /// Mixed `<p>` + `<ul>` + `<p>` with a non-trivial lineHeight.
    func testSnapshot_mixedParagraphsAndUnorderedList_withLineHeight() {
        let value = """
        <p>Alpha paragraph.</p>\
        <p>Bravo paragraph introducing a list:</p>\
        <ul>\
        <li>First item</li>\
        <li>Second item</li>\
        <li>Third item</li>\
        </ul>\
        <p>Charlie paragraph.</p>
        """
        let model = RichTextViewModel(
            value: value,
            defaultStyle: [richTextStyle(lineHeight: 20)],
            openLinks: nil,
            layoutState: LayoutState(),
            eventService: nil
        )
        assertRichTextSnapshot(model, height: 400)
    }

    /// Same shape as the mixed unordered test but with `<ol>` to lock
    /// numbered-list inter-item spacing at the same lineHeight.
    func testSnapshot_mixedParagraphsAndOrderedList_withLineHeight() {
        let value = """
        <p>Alpha paragraph introducing a numbered list:</p>\
        <ol>\
        <li>First step</li>\
        <li>Second step</li>\
        <li>Third step</li>\
        </ol>\
        <p>Bravo paragraph.</p>
        """
        let model = RichTextViewModel(
            value: value,
            defaultStyle: [richTextStyle(lineHeight: 20)],
            openLinks: nil,
            layoutState: LayoutState(),
            eventService: nil
        )
        assertRichTextSnapshot(model, height: 350)
    }

    /// Larger lineHeight (32pt) — heading-style typography. Confirms the
    /// gap scales with typography without becoming a blank line.
    func testSnapshot_paragraphs_withLargeLineHeight() {
        let model = RichTextViewModel(
            value: "<p>Alpha heading paragraph.</p><p>Bravo heading paragraph.</p>",
            defaultStyle: [richTextStyle(fontSize: 20, lineHeight: 32)],
            openLinks: nil,
            layoutState: LayoutState(),
            eventService: nil
        )
        assertRichTextSnapshot(model, height: 250)
    }

    // MARK: - List item CSS-margin parity snapshots

    //
    // CSS analogue: bare `<li>` has `margin: 0` so adjacent items sit flush.
    // A `<p>` child contributes its own margin, producing a visible gap
    // between adjacent `<li>` items. These snapshots pin both shapes with
    // a non-trivial lineHeight so the difference is visible.

    /// Bare `<li>` siblings — no inter-item gap, even with lineHeight set.
    func testSnapshot_bareListItems_withLineHeight() {
        let model = RichTextViewModel(
            value: "<ul><li>First bare item</li><li>Second bare item</li><li>Third bare item</li></ul>",
            defaultStyle: [richTextStyle(lineHeight: 20)],
            openLinks: nil,
            layoutState: LayoutState(),
            eventService: nil
        )
        assertRichTextSnapshot(model, height: 250)
    }

    /// `<li><p>...</p></li>` siblings — gap from the inherited `<p>` margin.
    func testSnapshot_listItemsWithParagraphs_withLineHeight() {
        let value = """
        <ul>\
        <li><p>First item with paragraph</p></li>\
        <li><p>Second item with paragraph</p></li>\
        <li><p>Third item with paragraph</p></li>\
        </ul>
        """
        let model = RichTextViewModel(
            value: value,
            defaultStyle: [richTextStyle(lineHeight: 20)],
            openLinks: nil,
            layoutState: LayoutState(),
            eventService: nil
        )
        assertRichTextSnapshot(model, height: 250)
    }

    /// Mixed siblings — locks the "previous-sibling carries the margin" rule:
    /// `<li><p>`-then-bare gets a gap (from the prior `<p>`), bare-then-`<li><p>`
    /// does not (the heuristic doesn't look ahead).
    func testSnapshot_mixedBareAndParagraphListItems_withLineHeight() {
        let value = """
        <ul>\
        <li><p>Paragraph item one</p></li>\
        <li>Bare item two</li>\
        <li>Bare item three</li>\
        <li><p>Paragraph item four</p></li>\
        </ul>
        """
        let model = RichTextViewModel(
            value: value,
            defaultStyle: [richTextStyle(lineHeight: 20)],
            openLinks: nil,
            layoutState: LayoutState(),
            eventService: nil
        )
        assertRichTextSnapshot(model, height: 300)
    }

    // MARK: - Helpers

    private func richTextStyle(fontSize: Float = 14, lineHeight: Float) -> RichTextStyle {
        RichTextStyle(
            dimension: nil,
            flexChild: nil,
            spacing: nil,
            background: nil,
            text: TextStylingProperties(
                textColor: nil,
                fontSize: fontSize,
                fontFamily: nil,
                fontWeight: nil,
                lineHeight: lineHeight,
                horizontalTextAlign: nil,
                baselineTextAlign: nil,
                fontStyle: nil,
                textTransform: nil,
                letterSpacing: nil,
                textDecoration: nil,
                lineLimit: nil
            )
        )
    }

    private func assertRichTextSnapshot(
        _ model: RichTextViewModel,
        colorMode: RoktUXConfig.ColorMode? = .light,
        width: CGFloat = 350,
        height: CGFloat = 200,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        model.transformValueToAttributedString(colorMode)
        waitForAttributedStringConversion(on: model, timeout: 2.0)

        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.richText(model))
            .frame(width: width, height: height)

        let hostingController = UIHostingController(rootView: view)
        assertSnapshot(of: hostingController, as: .image(on: snapshotDevice), file: file, testName: testName, line: line)
    }
    
    // MARK: - Nil / empty defaultStyle tests

    func test_rich_text_nil_default_style_still_parses_html() {
        let html = "<b>Bold</b> and <i>italic</i>"
        let model = RichTextViewModel(
            value: html,
            defaultStyle: nil,
            openLinks: nil,
            layoutState: LayoutState(),
            eventService: nil
        )
        model.transformValueToAttributedString(.light)
        waitForAttributedStringConversion(on: model, timeout: 2.0)

        XCTAssertEqual(model.attributedString.string, "Bold and italic")
        XCTAssertFalse(model.attributedString.string.contains("<b>"))
        XCTAssertFalse(model.attributedString.string.contains("<i>"))
    }

    func test_rich_text_empty_default_style_still_parses_html() {
        let html = "<b>Bold</b> and <i>italic</i>"
        let model = RichTextViewModel(
            value: html,
            defaultStyle: [],
            openLinks: nil,
            layoutState: LayoutState(),
            eventService: nil
        )
        model.transformValueToAttributedString(.light)
        waitForAttributedStringConversion(on: model, timeout: 2.0)

        XCTAssertEqual(model.attributedString.string, "Bold and italic")
        XCTAssertFalse(model.attributedString.string.contains("<b>"))
    }

    func test_rich_text_nil_text_property_still_parses_html() {
        let html = "<b>Bold</b> text"
        let style = RichTextStyle(dimension: nil, flexChild: nil, spacing: nil, background: nil, text: nil)
        let model = RichTextViewModel(
            value: html,
            defaultStyle: [style],
            openLinks: nil,
            layoutState: LayoutState(),
            eventService: nil
        )
        model.transformValueToAttributedString(.light)
        waitForAttributedStringConversion(on: model, timeout: 2.0)

        XCTAssertEqual(model.attributedString.string, "Bold text")
        XCTAssertFalse(model.attributedString.string.contains("<b>"))
    }

    func test_rich_text_nil_default_style_preserves_bold() {
        let html = "<b>Bold</b> normal"
        let model = RichTextViewModel(
            value: html,
            defaultStyle: nil,
            openLinks: nil,
            layoutState: LayoutState(),
            eventService: nil
        )
        model.transformValueToAttributedString(.light)
        waitForAttributedStringConversion(on: model, timeout: 2.0)

        XCTAssertEqual(model.attributedString.string, "Bold normal")

        let boldFont = model.attributedString.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(boldFont)
        XCTAssertEqual(boldFont?.fontDescriptor.symbolicTraits.contains(.traitBold), true)

        let plainFont = model.attributedString.attribute(.font, at: 5, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(plainFont)
        XCTAssertEqual(plainFont?.fontDescriptor.symbolicTraits.contains(.traitBold), false)
    }

    func test_rich_text_nil_default_style_preserves_link() {
        let html = "Click <a href='https://rokt.com'>here</a>"
        let model = RichTextViewModel(
            value: html,
            defaultStyle: nil,
            openLinks: nil,
            layoutState: LayoutState(),
            eventService: nil
        )
        model.transformValueToAttributedString(.light)
        waitForAttributedStringConversion(on: model, timeout: 2.0)

        XCTAssertEqual(model.attributedString.string, "Click here")
        let link = model.attributedString.attribute(.link, at: 6, effectiveRange: nil)
        XCTAssertNotNil(link)
    }

    func get_model() throws -> RichTextViewModel {
        let transformer = LayoutTransformer(layoutPlugin: get_mock_layout_plugin())
        let richText = try transformer.getRichText(ModelTestData.TextData.richTextHTML(), context: .outer([]))
        richText.transformValueToAttributedString(.light)
        waitForAttributedStringConversion(on: richText, timeout: 2.0)
        return richText
    }

    func get_state_model() throws -> RichTextViewModel {
        let transformer = LayoutTransformer(layoutPlugin: get_mock_layout_plugin())
        let richText = try transformer.getRichText(ModelTestData.TextData.richTextState(), context: .outer([]))
        richText.transformValueToAttributedString(.light)
        waitForAttributedStringConversion(on: richText, timeout: 2.0)
        return richText
    }

    private func waitForAttributedStringConversion(on model: RichTextViewModel, timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while model.attributedString.string.isEmpty && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
    }
    
    func get_dark_config_model() throws -> LayoutSchemaViewModel? {
        let transformer = LayoutTransformer(
            layoutPlugin: get_mock_layout_plugin(),
            layoutState: .init(
                config: RoktUXConfig.Builder().colorMode(.dark).build()
            )
        )
        return try transformer.transform()
    }
}

extension UIColor {
    func isEqualIgnoringSpaceContext(_ otherColor: UIColor) -> Bool {
        guard let selfAsCGColor = self.cgColor.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil)
            else {
            XCTFail("Could not convert to cgColor \(self)")
            return false
        }
        
        guard let otherAsCGColor = otherColor.cgColor.converted(
            to: CGColorSpaceCreateDeviceRGB(),
            intent: .defaultIntent,
            options: nil
        ) else {
            XCTFail("Could not convert to cgColor \(otherColor)")
            return false
        }
        
        return selfAsCGColor == otherAsCGColor
    }
}
