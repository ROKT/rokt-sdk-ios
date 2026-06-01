import XCTest
@testable import RoktUXHelper

final class OrphanedPlaceholderResolverTests: XCTestCase {

    // MARK: - Mandatory orphans (no `|` default) → fail-loud (nil return)

    func test_mandatoryOrphan_inUnclaimedNamespace_returnsNil() {
        // Creative-link placeholder that no mapper resolved AND no `|` fallback.
        let text = "%^DATA.creativeLink.termsAndConditions^%"

        XCTAssertNil(OrphanedPlaceholderResolver.resolve(text: text))
    }

    func test_mandatoryOrphan_mixedWithResolvedText_returnsNil() {
        // Even when the mandatory orphan sits next to plain text, the whole line fails.
        let text = "Read our terms here: %^DATA.creativeLink.termsAndConditions^%"

        XCTAssertNil(OrphanedPlaceholderResolver.resolve(text: text))
    }

    // MARK: - Optional orphans (with `|` default) → fallback substituted

    func test_optionalOrphan_substitutesDefaultLiteral() {
        let text = "%^DATA.creativeLink.foo | Read terms^%"

        XCTAssertEqual(OrphanedPlaceholderResolver.resolve(text: text), "Read terms")
    }

    func test_optionalOrphan_withEmptyDefault_substitutesEmptyString() {
        // `| ^%` ends with the alternative separator → defaultValue is "".
        let text = "Header%^DATA.creativeLink.foo|^%Footer"

        XCTAssertEqual(OrphanedPlaceholderResolver.resolve(text: text), "HeaderFooter")
    }

    func test_optionalOrphan_keepsSurroundingText() {
        let text = "Subtotal: %^DATA.creativeLink.foo | $0.00^% (estimated)"

        XCTAssertEqual(
            OrphanedPlaceholderResolver.resolve(text: text),
            "Subtotal: $0.00 (estimated)"
        )
    }

    // MARK: - Deferred namespaces → left untouched

    func test_catalogRuntimePlaceholder_isDeferred_andPreserved() {
        // catalogRuntime is resolved reactively when the host pushes data; resolver must
        // not zero the line just because runtime data hasn't arrived yet.
        let text = "Subtotal: %^DATA.catalogRuntime.subtotal | --^%"

        XCTAssertEqual(OrphanedPlaceholderResolver.resolve(text: text), text)
    }

    func test_catalogRuntimeMandatoryPlaceholder_isDeferred_notZeroed() {
        // Even without `|`, catalogRuntime placeholders defer to runtime resolution
        // rather than failing the line at finalize time.
        let text = "Total: %^DATA.catalogRuntime.total^%"

        XCTAssertEqual(OrphanedPlaceholderResolver.resolve(text: text), text)
    }

    func test_statePlaceholder_isDeferred_andPreserved() {
        // STATE.IndicatorPosition is resolved at render time inside BasicTextViewModel;
        // resolver must not zero or substitute it.
        let text = "Page %^STATE.IndicatorPosition^% of %^STATE.TotalOffers^%"

        XCTAssertEqual(OrphanedPlaceholderResolver.resolve(text: text), text)
    }

    // MARK: - No placeholders → unchanged

    func test_textWithoutPlaceholders_returnsUnchanged() {
        let text = "Plain marketing copy with no placeholders."

        XCTAssertEqual(OrphanedPlaceholderResolver.resolve(text: text), text)
    }

    // MARK: - Multiple orphans

    func test_multipleOptionalOrphans_allSubstituted() {
        let text = "%^DATA.creativeCopy.greeting | Hi^%, %^DATA.creativeLink.tnc | Read terms^%"

        XCTAssertEqual(
            OrphanedPlaceholderResolver.resolve(text: text),
            "Hi, Read terms"
        )
    }

    func test_oneMandatoryOrphan_amongOptionals_zeroesLine() {
        // Optionals would substitute, but the single mandatory orphan still fails the line.
        let text = "%^DATA.creativeLink.foo | fallback^% and %^DATA.creativeLink.bar^%"

        XCTAssertNil(OrphanedPlaceholderResolver.resolve(text: text))
    }

    func test_duplicateOptionalOrphans_bothFallbacksApply() {
        // Same token appears twice. A global `result.range(of:)` replacement would only
        // substitute the first occurrence; the second would leak raw `%^…^%` syntax.
        let text = "%^DATA.creativeLink.foo | a^% / %^DATA.creativeLink.foo | a^%"

        XCTAssertEqual(OrphanedPlaceholderResolver.resolve(text: text), "a / a")
    }

    func test_mixedDuplicateAndUniqueOrphans_allSubstituted() {
        let text = "%^DATA.creativeLink.foo | A^% %^DATA.creativeLink.bar | B^% %^DATA.creativeLink.foo | A^%"

        XCTAssertEqual(OrphanedPlaceholderResolver.resolve(text: text), "A B A")
    }

    // MARK: - Mixed: deferred + orphan

    func test_deferredAlongsideOptionalOrphan_substitutesOptional_keepsDeferred() {
        let text = "%^DATA.creativeLink.foo | --^% / %^DATA.catalogRuntime.subtotal^%"

        XCTAssertEqual(
            OrphanedPlaceholderResolver.resolve(text: text),
            "-- / %^DATA.catalogRuntime.subtotal^%"
        )
    }

    func test_deferredAlongsideMandatoryOrphan_stillZeroesLine() {
        let text = "%^DATA.creativeLink.foo^% / %^DATA.catalogRuntime.subtotal^%"

        XCTAssertNil(OrphanedPlaceholderResolver.resolve(text: text))
    }
}
