import Foundation
import UIKit
import Quick
import Nimble
@testable import Rokt_Widget

let kInvalidWidgetFilename = "invalidWidget"

class InvalidWidgetTests: QuickSpec {
    override func spec() {
        describe("Rokt modal controller") {
            var testVC: TestViewController!

            beforeEach {

                // Mock date
                RoktSDKDateHandler.customDate = timingsDate

                // Stub response for init call
                self.stubInit()

                // Stub response for widget call
                self.stubExecute(kInvalidWidgetFilename)

                // Stub response for event call
                self.stubEvents()

                // Stub response for diagnostic call
                self.stubDiagnostics()

                // Stub response for timings call
                self.stubTimings()

                testVC = TestViewController()

                UIApplication.shared.keyWindow!.rootViewController = testVC
                _ = testVC.view

            }

            it("is not shown after no widget to show") {
                waitUntil(timeout: .seconds(2)) { done in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                        expect(UIApplication.topViewController()).to(beAnInstanceOf(TestViewController.self))
                        done()
                    })
                }
            }

            afterEach {
                testVC = nil
                UIApplication.shared.keyWindow!.rootViewController = nil
            }
        }
    }
}
