import SwiftUI
import XCTest
@testable import Rokt_Widget

final class TestRoktEmbeddedViewLayout: XCTestCase {
    private var window: UIWindow!
    private var containerViewController: UIViewController!

    override func setUp() {
        super.setUp()
        containerViewController = UIViewController()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 812))
        window.rootViewController = containerViewController
        window.makeKeyAndVisible()
    }

    override func tearDown() {
        window.isHidden = true
        window = nil
        containerViewController = nil
        super.tearDown()
    }

    func testLoadPinsHostedViewWithBottomConstraint() {
        let embeddedView = makeEmbeddedViewInHierarchy(width: 320)

        embeddedView.load(onSizeChanged: { _ in }, injectedView: {
            Text("Embedded placement")
        })

        XCTAssertNotNil(embeddedView.bottomConstaint)
        XCTAssertTrue(embeddedView.bottomConstaint?.isActive ?? false)
        XCTAssertTrue(embeddedView.clipsToBounds)
    }

    func testLoadDisablesSafeAreaRegionsRegardlessOfFrameworkType() {
        guard #available(iOS 16.4, *) else { return }

        let embeddedView = makeEmbeddedViewInHierarchy(width: 320)

        embeddedView.load(onSizeChanged: { _ in }, injectedView: {
            Text("Embedded placement")
        })

        guard let hostingController = containerViewController.children.first(
            where: { $0 is UIHostingController<AnyView> }
        ) as? UIHostingController<AnyView> else {
            return XCTFail("Expected a hosting controller for the embedded view")
        }

        XCTAssertEqual(hostingController.safeAreaRegions, [])
    }

    func testUpdateEmbeddedSizeKeepsHostAndHostedBoundsEqualAfterLayout() {
        let embeddedView = makeEmbeddedViewInHierarchy(width: 320)
        let heightConstraint = embeddedView.heightAnchor.constraint(equalToConstant: 0)
        heightConstraint.isActive = true

        embeddedView.load(onSizeChanged: { _ in }, injectedView: {
            Text("Embedded placement")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        })

        let expectedHeight: CGFloat = 180
        embeddedView.updateEmbeddedSize(expectedHeight)
        layoutEmbeddedView(embeddedView)

        guard let hostedView = embeddedView.roktEmbeddedSwiftUIView else {
            return XCTFail("Expected a hosted SwiftUI view after load")
        }

        XCTAssertEqual(embeddedView.bounds.height, expectedHeight, accuracy: 0.5)
        XCTAssertEqual(hostedView.bounds.height, embeddedView.bounds.height, accuracy: 0.5)
        XCTAssertEqual(hostedView.frame.height, expectedHeight, accuracy: 0.5)
        XCTAssertEqual(heightConstraint.constant, expectedHeight, accuracy: 0.5)
    }

    func testLoadPreservesAutoLayoutWhenHostOptedInBeforeLoad() {
        let embeddedView = RoktEmbeddedView()
        embeddedView.translatesAutoresizingMaskIntoConstraints = false
        pinEmbeddedViewInContainer(embeddedView, width: 280)

        embeddedView.load(onSizeChanged: { _ in }, injectedView: {
            Text("Embedded placement")
        })

        XCTAssertFalse(embeddedView.translatesAutoresizingMaskIntoConstraints)
    }

    func testReloadRemovesAndRecreatesBottomConstraint() {
        let embeddedView = makeEmbeddedViewInHierarchy(width: 320)

        embeddedView.load(onSizeChanged: { _ in }, injectedView: {
            Text("First load")
        })
        let firstBottomConstraint = embeddedView.bottomConstaint

        embeddedView.load(onSizeChanged: { _ in }, injectedView: {
            Text("Second load")
        })

        XCTAssertNotNil(embeddedView.bottomConstaint)
        XCTAssertTrue(embeddedView.bottomConstaint?.isActive ?? false)
        XCTAssertNotEqual(ObjectIdentifier(firstBottomConstraint as AnyObject),
                          ObjectIdentifier(embeddedView.bottomConstaint as AnyObject))
    }

    private func makeEmbeddedViewInHierarchy(width: CGFloat) -> RoktEmbeddedView {
        let embeddedView = RoktEmbeddedView()
        embeddedView.translatesAutoresizingMaskIntoConstraints = false
        pinEmbeddedViewInContainer(embeddedView, width: width)
        return embeddedView
    }

    private func pinEmbeddedViewInContainer(_ embeddedView: RoktEmbeddedView, width: CGFloat) {
        containerViewController.view.addSubview(embeddedView)
        NSLayoutConstraint.activate([
            embeddedView.topAnchor.constraint(equalTo: containerViewController.view.safeAreaLayoutGuide.topAnchor),
            embeddedView.centerXAnchor.constraint(equalTo: containerViewController.view.centerXAnchor),
            embeddedView.widthAnchor.constraint(equalToConstant: width)
        ])
    }

    private func layoutEmbeddedView(_ embeddedView: RoktEmbeddedView) {
        containerViewController.view.setNeedsLayout()
        containerViewController.view.layoutIfNeeded()
        embeddedView.setNeedsLayout()
        embeddedView.layoutIfNeeded()
    }
}
