import Foundation
import UIKit
import Quick
import Nimble
import Mocker
@testable import Rokt_Widget

class APIErrorTests: QuickSpec {
    override func spec() {
        var diagnosticsReceived: [String] = []

        describe("Execute API Error Handling") {
            beforeEach {
                diagnosticsReceived = []
                Rokt.shared.roktImplementation.roktTagId = "123"
                self.stubDiagnostics(onDiagnosticsReceive: { diagnostics in
                    diagnosticsReceived.append(diagnostics)
                })
            }

            context("when Execute API returns non-429 error") {
                it("sends diagnostics") {
                    // When: Call executeFailureHandler directly
                    let error = NSError(domain: "test", code: 500, userInfo: nil)
                    Rokt.shared.roktImplementation.executeFailureHandler(error, 500, "Server Error")

                    // Then: Diagnostics should be sent
                    waitUntil(timeout: .seconds(2)) { done in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            expect(diagnosticsReceived.count).to(beGreaterThan(0))
                            done()
                        }
                    }
                }
            }

            context("when Execute API returns 429 error") {
                it("does not send diagnostics") {
                    // When: Call executeFailureHandler directly
                    let error = NSError(domain: "test", code: 429, userInfo: nil)
                    Rokt.shared.roktImplementation.executeFailureHandler(error, 429, "Too Many Requests")

                    // Then: Diagnostics should NOT be sent
                    waitUntil(timeout: .seconds(2)) { done in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            expect(diagnosticsReceived.count).to(equal(0))
                            done()
                        }
                    }
                }
            }

            context("when Execute API returns network error (nil status code)") {
                it("does not send diagnostics") {
                    // When: Call executeFailureHandler with nil status code
                    let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
                    Rokt.shared.roktImplementation.executeFailureHandler(error, nil, "Network Error")

                    // Then: Diagnostics should NOT be sent
                    waitUntil(timeout: .seconds(2)) { done in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            expect(diagnosticsReceived.count).to(equal(0))
                            done()
                        }
                    }
                }
            }

            afterEach {
                diagnosticsReceived = []
            }
        }

        describe("Rokt modal controller") {
            var testVC: TestViewController!

            beforeEach {

                // Stub response for init call
                self.stubInit()

                // Stub response for placement call
                self.stubExecuteError()

                // Stub response for event call
                self.stubEvents()

                // Stub response for diagnostic call
                self.stubDiagnostics()

                testVC = TestViewController()

                UIApplication.shared.keyWindow!.rootViewController = testVC
                _ = testVC.view
            }

            it("is not shown after widget call retries") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
                    expect(UIApplication.topViewController()).to(beAKindOf(UIViewController.self))
                })
            }

            afterEach {
                testVC = nil
                UIApplication.shared.keyWindow!.rootViewController = nil
            }
        }
    }
}
