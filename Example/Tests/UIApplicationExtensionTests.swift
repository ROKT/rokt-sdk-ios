import UIKit
import XCTest
@testable import Rokt_Widget

final class UIApplicationExtensionTests: XCTestCase {

    private var window: UIWindow!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        window = try XCTUnwrap(windows.first(where: \.isKeyWindow) ?? windows.first)
    }

    override func tearDown() {
        window?.rootViewController = nil
        window = nil
        super.tearDown()
    }

    func testSceneKeyWindowReturnsTheKeyWindow() {
        window.makeKeyAndVisible()

        let keyWindow = UIApplication.sceneKeyWindow()

        XCTAssertTrue(keyWindow === window)
        XCTAssertEqual(keyWindow?.isKeyWindow, true)
    }

    func testTopViewControllerStartsFromTheKeyWindowRoot() {
        let root = UIViewController()
        window.rootViewController = root
        window.makeKeyAndVisible()

        XCTAssertTrue(UIApplication.topViewController() === root)
    }
}
