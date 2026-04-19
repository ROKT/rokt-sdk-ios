import XCTest
@testable import Rokt_Widget

final class TestRoktMockAPI: XCTestCase {

    func test_initialize_enablesShoppableAdsFeatureFlags() {
        var capturedResponse: InitRespose?
        let expectation = expectation(description: "RoktMockAPI.initialize success")

        RoktMockAPI.initialize(
            roktTagId: "mock-tag",
            success: { response in
                capturedResponse = response
                expectation.fulfill()
            },
            failure: { _, _, _ in
                XCTFail("RoktMockAPI.initialize should not fail in happy path")
                expectation.fulfill()
            }
        )

        wait(for: [expectation], timeout: 1.0)

        let flags = try? XCTUnwrap(capturedResponse?.featureFlags)
        XCTAssertEqual(flags?.isShoppableAdsEnabled(), true,
                       "Mock builds must expose both post-purchase flags so selectShoppableAds() can be exercised end-to-end.")
    }
}
