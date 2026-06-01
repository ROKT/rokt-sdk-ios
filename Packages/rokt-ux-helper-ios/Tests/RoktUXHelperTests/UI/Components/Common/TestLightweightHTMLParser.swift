import XCTest
import SwiftUI
@testable import RoktUXHelper

@available(iOS 15.0, *)
final class TestLightweightHTMLParser: XCTestCase {

    private let baseFont = UIFont.systemFont(ofSize: 16)

    // MARK: - Plain text (no tags)

    func test_plain_text() {
        let result = LightweightHTMLParser.parse(html: "Hello World", baseFont: baseFont)
        XCTAssertEqual(result.string, "Hello World")

        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font, baseFont)
    }

    func test_empty_string() {
        let result = LightweightHTMLParser.parse(html: "", baseFont: baseFont)
        XCTAssertEqual(result.string, "")
    }

    // MARK: - Bold

    func test_bold_b_tag() {
        let result = LightweightHTMLParser.parse(html: "<b>Bold</b>", baseFont: baseFont)
        XCTAssertEqual(result.string, "Bold")

        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.fontDescriptor.symbolicTraits.contains(.traitBold), true)
    }

    func test_bold_strong_tag() {
        let result = LightweightHTMLParser.parse(html: "<strong>Bold</strong>", baseFont: baseFont)
        XCTAssertEqual(result.string, "Bold")

        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.fontDescriptor.symbolicTraits.contains(.traitBold), true)
    }

    // MARK: - Italic

    func test_italic_i_tag() {
        let result = LightweightHTMLParser.parse(html: "<i>Italic</i>", baseFont: baseFont)
        XCTAssertEqual(result.string, "Italic")

        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.fontDescriptor.symbolicTraits.contains(.traitItalic), true)
    }

    func test_italic_em_tag() {
        let result = LightweightHTMLParser.parse(html: "<em>Italic</em>", baseFont: baseFont)
        XCTAssertEqual(result.string, "Italic")

        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.fontDescriptor.symbolicTraits.contains(.traitItalic), true)
    }

    // MARK: - Underline

    func test_underline() {
        let result = LightweightHTMLParser.parse(html: "<u>Underlined</u>", baseFont: baseFont)
        XCTAssertEqual(result.string, "Underlined")

        let underline = result.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int
        XCTAssertEqual(underline, NSUnderlineStyle.single.rawValue)
    }

    // MARK: - Strikethrough

    func test_strikethrough_s_tag() {
        let result = LightweightHTMLParser.parse(html: "<s>Struck</s>", baseFont: baseFont)
        XCTAssertEqual(result.string, "Struck")

        let strike = result.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int
        XCTAssertEqual(strike, NSUnderlineStyle.single.rawValue)
    }

    func test_strikethrough_strike_tag() {
        let result = LightweightHTMLParser.parse(html: "<strike>Struck</strike>", baseFont: baseFont)
        XCTAssertEqual(result.string, "Struck")

        let strike = result.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int
        XCTAssertEqual(strike, NSUnderlineStyle.single.rawValue)
    }

    // MARK: - Links

    func test_link_with_href() {
        let result = LightweightHTMLParser.parse(
            html: "<a href=\"https://rokt.com\">Rokt</a>",
            baseFont: baseFont
        )
        XCTAssertEqual(result.string, "Rokt")

        let link = result.attribute(.link, at: 0, effectiveRange: nil) as? URL
        XCTAssertEqual(link, URL(string: "https://rokt.com"))
    }

    func test_link_with_target_attribute() {
        let result = LightweightHTMLParser.parse(
            html: "<a href=\"https://rokt.com/privacy\" target=\"_blank\">Privacy</a>",
            baseFont: baseFont
        )
        XCTAssertEqual(result.string, "Privacy")

        let link = result.attribute(.link, at: 0, effectiveRange: nil) as? URL
        XCTAssertEqual(link, URL(string: "https://rokt.com/privacy"))
    }

    // MARK: - Font color

    func test_font_color_unquoted() {
        let result = LightweightHTMLParser.parse(
            html: "<font color=#FF0000>Red</font>",
            baseFont: baseFont
        )
        XCTAssertEqual(result.string, "Red")

        let color = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertNotNil(color)
    }

    func test_font_color_quoted() {
        let result = LightweightHTMLParser.parse(
            html: "<font color=\"#00FF00\">Green</font>",
            baseFont: baseFont
        )
        XCTAssertEqual(result.string, "Green")

        let color = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertNotNil(color)
    }

    func test_font_color_does_not_bleed_outside_tag() {
        let result = LightweightHTMLParser.parse(
            html: "Before <font color=#FF0000>Red</font> After",
            baseFont: baseFont
        )
        XCTAssertEqual(result.string, "Before Red After")

        let colorInside = result.attribute(.foregroundColor, at: 7, effectiveRange: nil) as? UIColor
        XCTAssertNotNil(colorInside)

        let colorOutside = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertNil(colorOutside)
    }

    // MARK: - Line break

    func test_br_tag() {
        let result = LightweightHTMLParser.parse(html: "Line1<br>Line2", baseFont: baseFont)
        XCTAssertEqual(result.string, "Line1\nLine2")
    }

    func test_self_closing_br_tag() {
        let result = LightweightHTMLParser.parse(html: "Line1<br/>Line2", baseFont: baseFont)
        XCTAssertEqual(result.string, "Line1\nLine2")
    }

    // MARK: - Paragraph tag

    func test_p_tag_single_paragraph() {
        let result = LightweightHTMLParser.parse(html: "<p>Hello</p>", baseFont: baseFont)
        XCTAssertEqual(result.string, "Hello\n")

        let paragraphStyle = result.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertNotNil(paragraphStyle)
        XCTAssertGreaterThan(paragraphStyle?.paragraphSpacing ?? 0, 0)
    }

    func test_p_tag_two_paragraphs_separated_by_newline() {
        let result = LightweightHTMLParser.parse(html: "<p>First</p><p>Second</p>", baseFont: baseFont)
        // Spacer line (tiny-font NBSP) inserted between paragraphs to render the gap.
        XCTAssertEqual(result.string, "First\n\u{00A0}\nSecond\n")

        let firstStyle = result.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        let secondStyle = result.attribute(.paragraphStyle, at: 8, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertNotNil(firstStyle)
        XCTAssertNotNil(secondStyle)
    }

    func test_p_tag_after_inline_text_adds_break() {
        let result = LightweightHTMLParser.parse(html: "Intro<p>Body</p>", baseFont: baseFont)
        XCTAssertEqual(result.string, "Intro\n\u{00A0}\nBody\n")
    }

    func test_p_tag_with_inline_formatting_inside() {
        let result = LightweightHTMLParser.parse(html: "<p>Hello <b>bold</b> world</p>", baseFont: baseFont)
        XCTAssertEqual(result.string, "Hello bold world\n")

        let plainFont = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(plainFont?.fontDescriptor.symbolicTraits.contains(.traitBold), false)

        let boldFont = result.attribute(.font, at: 6, effectiveRange: nil) as? UIFont
        XCTAssertEqual(boldFont?.fontDescriptor.symbolicTraits.contains(.traitBold), true)
    }

    func test_p_tag_unclosed_still_renders() {
        let result = LightweightHTMLParser.parse(html: "<p>No close tag", baseFont: baseFont)
        XCTAssertEqual(result.string, "No close tag")
    }

    // MARK: - List tags

    func test_ul_with_single_li() {
        let result = LightweightHTMLParser.parse(html: "<ul><li>One</li></ul>", baseFont: baseFont)
        XCTAssertEqual(result.string, "• One\n")
    }

    func test_ul_with_multiple_li() {
        let result = LightweightHTMLParser.parse(html: "<ul><li>One</li><li>Two</li><li>Three</li></ul>", baseFont: baseFont)
        // Bare <li> siblings sit flush (CSS analogue: li.margin = 0).
        XCTAssertEqual(result.string, "• One\n• Two\n• Three\n")
    }

    func test_ol_numbers_items_sequentially() {
        let result = LightweightHTMLParser.parse(html: "<ol><li>One</li><li>Two</li><li>Three</li></ol>", baseFont: baseFont)
        XCTAssertEqual(result.string, "1. One\n2. Two\n3. Three\n")
    }

    func test_li_with_inline_formatting() {
        let result = LightweightHTMLParser.parse(html: "<ul><li>Plain <b>bold</b></li></ul>", baseFont: baseFont)
        XCTAssertEqual(result.string, "• Plain bold\n")

        // "• Plain " is 8 chars (•, space, P, l, a, i, n, space) — bold starts at index 8
        let boldFont = result.attribute(.font, at: 8, effectiveRange: nil) as? UIFont
        XCTAssertEqual(boldFont?.fontDescriptor.symbolicTraits.contains(.traitBold), true)
    }

    func test_whitespace_between_list_tags_stripped() {
        let html = "<ul>\n  <li>One</li>\n  <li>Two</li>\n</ul>"
        let result = LightweightHTMLParser.parse(html: html, baseFont: baseFont)
        XCTAssertEqual(result.string, "• One\n• Two\n")
    }

    func test_li_without_enclosing_list_renders_plain() {
        let result = LightweightHTMLParser.parse(html: "<li>orphan</li>", baseFont: baseFont)
        XCTAssertEqual(result.string, "orphan")
    }

    func test_unclosed_ul_does_not_crash() {
        let result = LightweightHTMLParser.parse(html: "<ul><li>One</li>", baseFont: baseFont)
        XCTAssertEqual(result.string, "• One\n")
    }

    func test_ol_counter_resets_per_list() {
        let html = "<ol><li>A</li><li>B</li></ol><ol><li>X</li><li>Y</li></ol>"
        let result = LightweightHTMLParser.parse(html: html, baseFont: baseFont)
        // Bare items sit flush; the spacer between the two consecutive lists
        // comes from <ol> opening (block separator), not inter-item spacing.
        XCTAssertEqual(result.string, "1. A\n2. B\n\u{00A0}\n1. X\n2. Y\n")
    }

    func test_li_open_implicitly_closes_previous_sibling() {
        // <ul><li>One<li>Two</li></ul> — second <li> implicitly closes the first
        // (valid HTML5). Both items must render with the marker prefix.
        let html = "<ul><li>One<li>Two</li></ul>"
        let result = LightweightHTMLParser.parse(html: html, baseFont: baseFont)
        XCTAssertEqual(result.string, "• One\n• Two\n")
    }

    func test_ol_implicit_li_close_increments_counter() {
        // <ol><li>A<li>B</li></ol> — implicit close must still bump the counter.
        let result = LightweightHTMLParser.parse(html: "<ol><li>A<li>B</li></ol>", baseFont: baseFont)
        XCTAssertEqual(result.string, "1. A\n2. B\n")
    }

    func test_p_inside_li_does_not_break_after_marker() {
        // <li><p>Text</p></li> is common WYSIWYG output. The <p> open must not
        // insert a newline immediately after the marker prefix.
        let result = LightweightHTMLParser.parse(html: "<ul><li><p>Text</p></li></ul>", baseFont: baseFont)
        XCTAssertEqual(result.string, "• Text\n")
    }

    func test_li_with_p_siblings_get_inter_item_spacer() {
        // CSS analogue: <p>'s `margin: 1em 0` shows through `<li>`'s zero
        // margin, producing a gap between adjacent items. We approximate
        // that gap with the block spacer.
        let html = "<ul><li><p>One</p></li><li><p>Two</p></li><li><p>Three</p></li></ul>"
        let result = LightweightHTMLParser.parse(html: html, baseFont: baseFont)
        XCTAssertEqual(result.string, "• One\n\u{00A0}\n• Two\n\u{00A0}\n• Three\n")
    }

    func test_mixed_bare_then_p_li_no_spacer() {
        // <li>A</li><li><p>B</p></li> — previous sibling had no block child,
        // so no spacer is emitted before the second marker. (Edge case: a
        // browser would still show a gap from the second <p>'s top margin.
        // The simpler "previous-sibling-only" rule keeps the parser local
        // and is good enough for the WYSIWYG patterns we see in practice.)
        let html = "<ul><li>A</li><li><p>B</p></li></ul>"
        let result = LightweightHTMLParser.parse(html: html, baseFont: baseFont)
        XCTAssertEqual(result.string, "• A\n• B\n")
    }

    func test_mixed_p_then_bare_li_emits_spacer() {
        // <li><p>A</p></li><li>B</li> — previous sibling had a <p> child, so
        // its trailing margin must show through. Spacer emitted before B.
        let html = "<ul><li><p>A</p></li><li>B</li></ul>"
        let result = LightweightHTMLParser.parse(html: html, baseFont: baseFont)
        XCTAssertEqual(result.string, "• A\n\u{00A0}\n• B\n")
    }

    func test_p_after_text_in_li_still_breaks() {
        // <li>Intro<p>Body</p></li> — when the <p> is not the first content,
        // a newline IS needed so "Intro" and "Body" don't run together. A
        // spacer line is also inserted between them (see paragraphSpacer).
        let result = LightweightHTMLParser.parse(html: "<ul><li>Intro<p>Body</p></li></ul>", baseFont: baseFont)
        XCTAssertEqual(result.string, "• Intro\n\u{00A0}\nBody\n")
    }

    func test_list_marker_inherits_font_color() {
        let result = LightweightHTMLParser.parse(
            html: "<font color=#FF0000><ul><li>Item</li></ul></font>",
            baseFont: baseFont
        )
        let bulletColor = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertNotNil(bulletColor, "List marker must inherit font color from surrounding context")
    }

    func test_list_marker_inherits_bold() {
        let result = LightweightHTMLParser.parse(html: "<b><ul><li>Item</li></ul></b>", baseFont: baseFont)
        let bulletFont = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(
            bulletFont?.fontDescriptor.symbolicTraits.contains(.traitBold),
            true,
            "List marker must inherit bold from surrounding <b>"
        )
    }

    func test_p_tag_implicit_close_preserves_previous_paragraph() {
        // <p>First<p>Second</p> — second <p> implicitly closes the first.
        // Both paragraphs must receive a paragraph style with spacing; a
        // spacer line is inserted between them.
        let result = LightweightHTMLParser.parse(html: "<p>First<p>Second</p>", baseFont: baseFont)
        XCTAssertEqual(result.string, "First\n\u{00A0}\nSecond\n")

        let firstStyle = result.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertNotNil(firstStyle, "First paragraph must keep its paragraph style after implicit close")
        XCTAssertGreaterThan(firstStyle?.paragraphSpacing ?? 0, 0)

        let secondStyle = result.attribute(.paragraphStyle, at: 8, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertNotNil(secondStyle)
    }

    func test_p_tag_paragraph_style_does_not_apply_to_text_outside() {
        let result = LightweightHTMLParser.parse(html: "Before <p>Inside</p> After", baseFont: baseFont)
        // Spacer line inserted between "Before " and "Inside":
        // "Before \n\u{00A0}\nInside\n After"
        XCTAssertEqual(result.string, "Before \n\u{00A0}\nInside\n After")

        let outsideBefore = result.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertNil(outsideBefore)

        // Index 10 is the first char of "Inside" — inside the <p> range.
        let insideStyle = result.attribute(.paragraphStyle, at: 10, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertNotNil(insideStyle)

        // Index 18 is the space before "After" — outside the <p> range.
        let outsideAfter = result.attribute(.paragraphStyle, at: 18, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertNil(outsideAfter)
    }

    // MARK: - Nested tags (DCUI fixture)

    func test_dcui_fixture_strong_em_u_s() {
        let html = "<strong><em><u>ORDER</u> <s>Number</s>: Uk171359906</em></strong>"
        let result = LightweightHTMLParser.parse(html: html, baseFont: baseFont)

        XCTAssertEqual(result.string, "ORDER Number: Uk171359906")

        let fontAtZero = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(fontAtZero?.fontDescriptor.symbolicTraits.contains(.traitBold), true)
        XCTAssertEqual(fontAtZero?.fontDescriptor.symbolicTraits.contains(.traitItalic), true)

        let underlineRange = NSRange(location: 0, length: 5)
        let underlineAttr = result.attributedSubstring(from: underlineRange)
        underlineAttr.enumerateAttributes(in: NSRange(location: 0, length: 5), options: []) { dict, _, _ in
            XCTAssertTrue(dict.keys.contains(.underlineStyle))
        }

        let strikeRange = NSRange(location: 6, length: 6)
        let strikeAttr = result.attributedSubstring(from: strikeRange)
        strikeAttr.enumerateAttributes(in: NSRange(location: 0, length: 6), options: []) { dict, _, _ in
            XCTAssertTrue(dict.keys.contains(.strikethroughStyle))
        }
    }

    func test_dcui_fixture_with_font_color_wrapper() {
        let html = "<font color=#AABBCC><strong><em><u>ORDER</u> <s>Number</s>: Uk171359906</em></strong></font>"
        let result = LightweightHTMLParser.parse(html: html, baseFont: baseFont)

        XCTAssertEqual(result.string, "ORDER Number: Uk171359906")

        let foregroundColor = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertNotNil(foregroundColor)
        XCTAssertEqual(foregroundColor?.isEqualIgnoringSpaceContext(UIColor(hexString: "#AABBCC")), true)
    }

    // MARK: - Bold + Italic combined

    func test_bold_italic_combined() {
        let result = LightweightHTMLParser.parse(html: "<b><i>BoldItalic</i></b>", baseFont: baseFont)
        XCTAssertEqual(result.string, "BoldItalic")

        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.fontDescriptor.symbolicTraits.contains(.traitBold), true)
        XCTAssertEqual(font?.fontDescriptor.symbolicTraits.contains(.traitItalic), true)
    }

    // MARK: - Mixed styled and unstyled text

    func test_partial_bold() {
        let result = LightweightHTMLParser.parse(html: "Get <b>20% off</b> today", baseFont: baseFont)
        XCTAssertEqual(result.string, "Get 20% off today")

        let fontPlain = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(fontPlain?.fontDescriptor.symbolicTraits.contains(.traitBold), false)

        let fontBold = result.attribute(.font, at: 4, effectiveRange: nil) as? UIFont
        XCTAssertEqual(fontBold?.fontDescriptor.symbolicTraits.contains(.traitBold), true)

        let fontAfter = result.attribute(.font, at: 12, effectiveRange: nil) as? UIFont
        XCTAssertEqual(fontAfter?.fontDescriptor.symbolicTraits.contains(.traitBold), false)
    }

    // MARK: - Nil base font (falls back to system font)

    func test_nil_base_font_still_applies_bold() {
        let result = LightweightHTMLParser.parse(html: "<b>Bold</b>", baseFont: nil)
        XCTAssertEqual(result.string, "Bold")

        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(font)
        XCTAssertEqual(font?.fontDescriptor.symbolicTraits.contains(.traitBold), true)
    }

    func test_nil_base_font_still_applies_italic() {
        let result = LightweightHTMLParser.parse(html: "<i>Italic</i>", baseFont: nil)
        XCTAssertEqual(result.string, "Italic")

        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(font)
        XCTAssertEqual(font?.fontDescriptor.symbolicTraits.contains(.traitItalic), true)
    }

    func test_nil_base_font_uses_system_font_size() {
        let result = LightweightHTMLParser.parse(html: "Plain", baseFont: nil)
        XCTAssertEqual(result.string, "Plain")

        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(font)
        XCTAssertEqual(font?.pointSize, UIFont.systemFontSize)
    }

    // MARK: - HTML entities

    func test_html_entities_amp_lt_gt() {
        let result = LightweightHTMLParser.parse(html: "A &amp; B &lt; C &gt; D", baseFont: baseFont)
        XCTAssertEqual(result.string, "A & B < C > D")
    }

    func test_html_entities_quot_apos() {
        let result = LightweightHTMLParser.parse(html: "&quot;hello&quot; &apos;world&apos;", baseFont: baseFont)
        XCTAssertEqual(result.string, "\"hello\" 'world'")
    }

    func test_html_entity_nbsp() {
        let result = LightweightHTMLParser.parse(html: "no&nbsp;break", baseFont: baseFont)
        XCTAssertEqual(result.string, "no\u{00A0}break")
    }

    func test_numeric_decimal_entity() {
        let result = LightweightHTMLParser.parse(html: "&#65;&#66;&#67;", baseFont: baseFont)
        XCTAssertEqual(result.string, "ABC")
    }

    func test_numeric_hex_entity() {
        let result = LightweightHTMLParser.parse(html: "&#x41;&#x42;&#x43;", baseFont: baseFont)
        XCTAssertEqual(result.string, "ABC")
    }

    func test_unknown_entity_preserved() {
        let result = LightweightHTMLParser.parse(html: "&unknown;", baseFont: baseFont)
        XCTAssertEqual(result.string, "&unknown;")
    }

    // MARK: - Case insensitivity

    func test_uppercase_tags() {
        let result = LightweightHTMLParser.parse(html: "<B>Bold</B>", baseFont: baseFont)
        XCTAssertEqual(result.string, "Bold")

        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.fontDescriptor.symbolicTraits.contains(.traitBold), true)
    }

    func test_mixed_case_tags() {
        let result = LightweightHTMLParser.parse(html: "<Strong>Bold</Strong>", baseFont: baseFont)
        XCTAssertEqual(result.string, "Bold")

        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.fontDescriptor.symbolicTraits.contains(.traitBold), true)
    }

    // MARK: - Malformed HTML resilience

    func test_unclosed_tag_still_renders_text() {
        let result = LightweightHTMLParser.parse(html: "<b>Bold text", baseFont: baseFont)
        XCTAssertEqual(result.string, "Bold text")

        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.fontDescriptor.symbolicTraits.contains(.traitBold), true)
    }

    func test_stray_less_than() {
        let result = LightweightHTMLParser.parse(html: "A < B", baseFont: baseFont)
        XCTAssertTrue(result.string.contains("A"))
        XCTAssertTrue(result.string.contains("B"))
    }

    func test_empty_tag() {
        let result = LightweightHTMLParser.parse(html: "Before<>After", baseFont: baseFont)
        XCTAssertTrue(result.string.contains("Before"))
        XCTAssertTrue(result.string.contains("After"))
    }

    // MARK: - Integration with htmlToAttributedString extension

    func test_htmlToAttributedString_uses_parser() {
        let result = "Get <b>20% off</b>".htmlToAttributedString(
            textColorHex: "#FF0000",
            uiFont: baseFont,
            linkStyles: nil,
            colorScheme: .light
        )
        XCTAssertEqual(result.string, "Get 20% off")

        let color = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertNotNil(color)
    }

    func test_htmlToAttributedString_without_color() {
        let result = "<em>Italic</em> text".htmlToAttributedString(
            textColorHex: nil,
            uiFont: baseFont,
            linkStyles: nil,
            colorScheme: .light
        )
        XCTAssertEqual(result.string, "Italic text")

        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.fontDescriptor.symbolicTraits.contains(.traitItalic), true)
    }
}
