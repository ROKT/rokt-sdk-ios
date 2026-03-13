import UIKit
@testable import Rokt_Widget

class TestViewController: UIViewController {

    var displayedOnce = false
    var closingCallbackCalled = false
    var onShouldShowCallbackCalled = false
    var onShouldHideCallbackCalled = false
    var hideLocation1 = false
    var attachLocation1 = true
    var cutOffParentSize: CGSize?
    var pageInitAttr: String?
    var embeddedLocation1, embeddedLocation2, embeddedLocation4: RoktEmbeddedView!

    override func viewDidLoad() {
        intitialSDK()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        executeSDK()
    }

    fileprivate func intitialSDK() {
        Rokt.initWith(roktTagId: "test_tag_id")
    }

    fileprivate func executeSDK() {
        attachEmbeddedLocations()
        let placements: [String: RoktEmbeddedView] = ["Location1": embeddedLocation1,
                                                      "Location2": embeddedLocation2,
                                                      "Location4": embeddedLocation4]

        // Testing showing in viewDidAppear to avoid "view is not in the window hierarchy" error when running tests
        // Showing works correctly in viewDidLoad in normal execution

        if !displayedOnce {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                var attributes = ["email": "jenny123123@rokt.com",
                                  "firstname": "jenny",
                                  "lastname": "anonymous",
                                  "mobile": "0444444444",
                                  "postcode": "2000"]

                if let pageInitAttr = self.pageInitAttr {
                    attributes[BE_ATTRIBUTES_PAGE_INIT_KEY] = pageInitAttr
                }

                Rokt.selectPlacements(
                    identifier: "Test",
                    attributes: attributes,
                    placements: placements,
                    onEvent: { roktEvent in
                        if roktEvent is RoktEvent.ShowLoadingIndicator {
                            self.onShouldShowCallbackCalled = true
                        } else if roktEvent is RoktEvent.HideLoadingIndicator {
                            self.onShouldHideCallbackCalled = true
                        } else if roktEvent is RoktEvent.PlacementClosed {
                            self.closingCallbackCalled = true
                        } else if roktEvent is RoktEvent.PlacementInteractive {
                            if !self.attachLocation1 {
                                self.view.addSubview(self.embeddedLocation1)
                            }
                            self.displayedOnce = true
                        }
                    }
                )
            }
        }
    }

    fileprivate func attachEmbeddedLocations() {

        if let cutOffParentSize = self.cutOffParentSize {
            let cutOffFrame = CGRect(origin: self.view.frame.origin, size: cutOffParentSize)
            self.view.frame = cutOffFrame
        }

        embeddedLocation1 = RoktEmbeddedView(frame: CGRect(x: 0, y: 50, width: self.view.frame.width, height: 0))
        embeddedLocation2 = RoktEmbeddedView(frame: CGRect(x: 0, y: 200, width: self.view.frame.width, height: 0))
        embeddedLocation4 = RoktEmbeddedView(frame: CGRect(x: 0, y: 200, width: self.view.frame.width, height: 0))
        if self.attachLocation1 {
            self.view.addSubview(embeddedLocation1)
        }
        self.view.addSubview(embeddedLocation2)
        self.view.addSubview(embeddedLocation4)

        if self.hideLocation1 {
            embeddedLocation1.isHidden = true
        }
    }

}
