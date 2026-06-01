import XCTest
@testable import RoktUXHelper

@available(iOS 15.0, *)
final class TestRoktUXPresentationResolver: XCTestCase {
    func testStableTopViewControllerSkipsUnusablePresentedController() {
        let root = StubPresentedViewController()
        let stalePresented = StubPresentedViewController()
        root.stubPresentedViewController = stalePresented

        let presenter = RoktUXPresentationResolver.stableTopViewController(
            startingAt: root,
            isPresenterUsable: { $0 === root }
        )

        XCTAssertTrue(presenter === root)
    }

    func testStableTopViewControllerReturnsDeepestUsablePresentedController() {
        let root = StubPresentedViewController()
        let firstPresented = StubPresentedViewController()
        let secondPresented = StubPresentedViewController()
        root.stubPresentedViewController = firstPresented
        firstPresented.stubPresentedViewController = secondPresented

        let presenter = RoktUXPresentationResolver.stableTopViewController(
            startingAt: root,
            isPresenterUsable: { _ in true }
        )

        XCTAssertTrue(presenter === secondPresented)
    }

    func testStableTopViewControllerReturnsNilWhenRootIsUnusable() {
        let root = StubPresentedViewController()

        let presenter = RoktUXPresentationResolver.stableTopViewController(
            startingAt: root,
            isPresenterUsable: { _ in false }
        )

        XCTAssertNil(presenter)
    }
}

private final class StubPresentedViewController: UIViewController {
    var stubPresentedViewController: UIViewController?

    override var presentedViewController: UIViewController? {
        stubPresentedViewController
    }
}
