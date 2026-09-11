import XCTest

/// Drives a real embedded placement through its whole offer cycle in the sample app, with no
/// human input, and asserts on what the host was told.
///
/// Runs against the offline Mock transports and the bundled `offers.json`, so the offer count and
/// the response copy are fixed rather than backend-dependent.
final class EmbeddedPlacementLifecycleUITests: XCTestCase {

    private let placement = "Location1"
    private let offerCount = 3
    /// The positive response label in the bundled fixture. The layout's `responseKey` renders
    /// only this one, so it is the control that advances the distribution.
    private let advanceLabel = "Apply Now"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testEmbeddedPlacementCollapsesAfterCyclingEveryOffer() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-roktAutoRun", "1",
            "-roktTagId", "automation-tag",
            "-roktPageIdentifier", "automation",
            "-roktLocation", placement
        ]
        app.launch()

        let transcript = AutomationTranscriptReader(app: app)

        XCTAssertTrue(
            transcript.waitForEvent(named: "PlacementInteractive"),
            "placement never reached the screen. Transcript:\n\(transcript.debugDescription)"
        )
        XCTAssertNotNil(
            transcript.lastPublishedHeight(forPlacement: placement),
            "no height was published for \(placement). Transcript:\n\(transcript.debugDescription)"
        )

        for offer in 1...offerCount {
            XCTAssertTrue(
                app.staticTexts["Automation offer \(offer) of \(offerCount)"].waitForExistence(timeout: 20),
                "offer \(offer) never rendered. Transcript:\n\(transcript.debugDescription)"
            )
            try advanceOffer(in: app, offer: offer)
        }

        // End of offers. The renderer collapses its own view; the host can only follow if it is
        // told, so the published height is the signal that matters.
        // The host-facing size change is debounced, so a late delivery needs time to land. There
        // is no event to wait on here — its absence is precisely what is under test — so this is
        // an honest fixed delay rather than a poll.
        Thread.sleep(forTimeInterval: 3)

        let publishedHeight = transcript.lastPublishedHeight(forPlacement: placement)
        let hostHeight = transcript.lastHostHeight(forPlacement: placement)
        // The SDK's own view, read from the accessibility tree rather than the transcript, so the
        // two sides of the collapse are measured independently. `closeEmbedded` removes the
        // hosted content, so a collapsed view drops out of the tree rather than reporting zero.
        let sdkView = app.otherElements["rokt-embedded-\(placement)"]
        let sdkCollapsed = !sdkView.exists || sdkView.frame.height < 0.5
        print("RECREATE_RESULT published=\(String(describing: publishedHeight)) "
            + "host=\(String(describing: hostHeight)) sdkCollapsed=\(sdkCollapsed)")

        // The renderer's teardown is synchronous and unaffected by the defect below, so this
        // holds either way and pins which side of the boundary failed.
        XCTAssertTrue(
            sdkCollapsed,
            "the SDK's own embedded view should be collapsed once every offer is cycled"
        )

        // End of offers. The renderer collapses its own view; the host can only follow if it is
        // told, so the published height is the signal that matters.
        let reason = "Known defect: the final EmbeddedSizeChanged is dropped because the debounced "
            + "delivery outlives the state bag that unload tears down. Remove this expectation "
            + "once that is fixed."
        XCTExpectFailure(reason) {
            XCTAssertEqual(
                publishedHeight, 0,
                "expected a final published height of 0 once every offer was cycled, got "
                    + "\(String(describing: publishedHeight)); the host settled at "
                    + "\(String(describing: hostHeight)). Transcript:\n\(transcript.debugDescription)"
            )
        }
    }

    /// Taps the response control for the current offer. Every tappable DCUI element carries the
    /// button trait, but the label comes from creative copy, so match on the fixture's own text
    /// and fall back to the static text if the trait did not land on a button element.
    private func advanceOffer(in app: XCUIApplication, offer: Int) throws {
        let button = app.buttons[advanceLabel].firstMatch
        if button.waitForExistence(timeout: 10) {
            button.tap()
            return
        }

        let text = app.staticTexts[advanceLabel].firstMatch
        guard text.waitForExistence(timeout: 10) else {
            print("ACCESSIBILITY_TREE\n\(app.debugDescription)")
            XCTFail("no \(advanceLabel) control found for offer \(offer)")
            return
        }
        text.tap()
    }
}
