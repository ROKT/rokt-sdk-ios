import XCTest
@testable import Rokt_Widget

class TestMParticleKitDetails: XCTestCase {

    func testInitializationAndProperties() {
        // Given
        let expectedSdkVersion = "1.2.3"
        let expectedKitVersion = "4.5.6"

        // When
        let details = MParticleKitDetails(sdkVersion: expectedSdkVersion, kitVersion: expectedKitVersion)

        // Then
        XCTAssertEqual(details.sdkVersion, expectedSdkVersion, "SDK version should match the initialized value")
        XCTAssertEqual(details.kitVersion, expectedKitVersion, "Kit version should match the initialized value")
    }
}
