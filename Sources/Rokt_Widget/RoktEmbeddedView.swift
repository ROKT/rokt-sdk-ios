import ObjectiveC
import SwiftUI
import UIKit
internal import RoktUXHelper

// MARK: - Associated Object Keys

private var roktEmbeddedSwiftUIViewKey: UInt8 = 0
private var topConstraintKey: UInt8 = 0
private var leadingConstraintKey: UInt8 = 0
private var trailingConstraintKey: UInt8 = 0
private var heightConstraintKey: UInt8 = 0
private var latestHeightKey: UInt8 = 0
private var onSizeChangeKey: UInt8 = 0

// MARK: - RoktEmbeddedView Internal Properties (via associated objects)

extension RoktEmbeddedView {
    var roktEmbeddedSwiftUIView: UIView? {
        get { objc_getAssociatedObject(self, &roktEmbeddedSwiftUIViewKey) as? UIView }
        set { objc_setAssociatedObject(self, &roktEmbeddedSwiftUIViewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var topConstaint: NSLayoutConstraint? {
        get { objc_getAssociatedObject(self, &topConstraintKey) as? NSLayoutConstraint }
        set { objc_setAssociatedObject(self, &topConstraintKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var leadingConstaint: NSLayoutConstraint? {
        get { objc_getAssociatedObject(self, &leadingConstraintKey) as? NSLayoutConstraint }
        set { objc_setAssociatedObject(self, &leadingConstraintKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var trailingConstaint: NSLayoutConstraint? {
        get { objc_getAssociatedObject(self, &trailingConstraintKey) as? NSLayoutConstraint }
        set { objc_setAssociatedObject(self, &trailingConstraintKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var heightConstaint: NSLayoutConstraint? {
        get { objc_getAssociatedObject(self, &heightConstraintKey) as? NSLayoutConstraint }
        set { objc_setAssociatedObject(self, &heightConstraintKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    // The default is -1 as 0 is a valid state. -1 means embedded view is not loaded correctly
    var latestHeight: CGFloat {
        get { (objc_getAssociatedObject(self, &latestHeightKey) as? NSNumber)?.doubleValue ?? -1 }
        set { objc_setAssociatedObject(self, &latestHeightKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var onSizeChange: ((CGFloat) -> Void)? {
        get { objc_getAssociatedObject(self, &onSizeChangeKey) as? (CGFloat) -> Void }
        set { objc_setAssociatedObject(self, &onSizeChangeKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    public func updateEmbeddedSize(_ size: CGFloat) {
        if roktEmbeddedSwiftUIView != nil {
            RoktLogger.shared.debug("Embedded height resized to \(size)")
            for cons in self.constraints where cons.firstAttribute == NSLayoutConstraint.Attribute.height {
                cons.constant = size
                cons.isActive = true
            }
            self.frame = CGRect(x: self.frame.minX, y: self.frame.minY, width: self.frame.width, height: size)
            roktEmbeddedSwiftUIView?.frame = CGRect(x: 0, y: 0, width: self.frame.width, height: size)
            latestHeight = size
        }
    }

    private func decideTranslatesAutoresizingMask() {
        if !self.constraints.isEmpty {
            self.translatesAutoresizingMaskIntoConstraints = false
        } else {
            self.translatesAutoresizingMaskIntoConstraints = true
        }
    }

    private func cleanupEmbeddedView() {
        subviews.forEach({ $0.removeFromSuperview() })
        removeEmbeddedLayoutConstraint(topConstaint)
        removeEmbeddedLayoutConstraint(leadingConstaint)
        removeEmbeddedLayoutConstraint(trailingConstaint)
        removeEmbeddedLayoutConstraint(heightConstaint)
    }

    private func addEmbeddedLayoutConstraints(embeddedView: UIView) {
        topConstaint = NSLayoutConstraint(item: self, attribute: .top,
                                          relatedBy: .equal, toItem: embeddedView,
                                          attribute: .top, multiplier: 1, constant: 0)
        leadingConstaint = NSLayoutConstraint(item: self, attribute: .leading,
                                              relatedBy: .equal, toItem: embeddedView,
                                              attribute: .leading, multiplier: 1, constant: 0)
        trailingConstaint = NSLayoutConstraint(item: self, attribute: .trailing,
                                               relatedBy: .equal, toItem: embeddedView,
                                               attribute: .trailing, multiplier: 1, constant: 0)
        heightConstaint = NSLayoutConstraint(item: self, attribute: .height,
                                             relatedBy: .equal, toItem: nil,
                                             attribute: .notAnAttribute, multiplier: 1, constant: 0)
        addEmbeddedLayoutConstraint(topConstaint)
        addEmbeddedLayoutConstraint(leadingConstaint)
        addEmbeddedLayoutConstraint(trailingConstaint)
        addEmbeddedLayoutConstraint(heightConstaint)
    }

    private func addEmbeddedLayoutConstraint(_ layoutConstraint: NSLayoutConstraint?) {
        if let layoutConstraint {
            self.addConstraint(layoutConstraint)
        }
    }

    private func removeEmbeddedLayoutConstraint(_ layoutConstraint: NSLayoutConstraint?) {
        if let layoutConstraint {
            self.removeConstraint(layoutConstraint)
        }
    }
}

// MARK: - ResizableHostingController

class ResizableHostingController<Content>: UIHostingController<Content> where Content: View {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.view.invalidateIntrinsicContentSize()
    }
}

// MARK: - UIResponder Extension

extension UIResponder {
    @objc public var parentViewControllers: UIViewController? {
        return next as? UIViewController ?? next?.parentViewControllers
    }
}

// MARK: - InternalLayoutLoader Conformance

extension RoktEmbeddedView: InternalLayoutLoader {
    public func load<Content>(onSizeChanged: @escaping ((CGFloat) -> Void),
                              injectedView: @escaping () -> Content) where Content: View {
        cleanupEmbeddedView()
        self.onSizeChange = onSizeChanged
        let vc = ResizableHostingController(rootView: AnyView(injectedView()))
        if #available(iOS 16.4, *),
           Rokt.shared.roktImplementation.frameworkType == .Flutter {
            vc.safeAreaRegions = []
        }

        let swiftuiView = vc.view!
        self.roktEmbeddedSwiftUIView = swiftuiView

        parentViewControllers?.addChild(vc)
        swiftuiView.translatesAutoresizingMaskIntoConstraints = false

        decideTranslatesAutoresizingMask()

        addSubview(swiftuiView)
        RoktLogger.shared.info("Embedded view attached to the screen")

        self.frame = CGRect(x: self.frame.minX, y: self.frame.minY, width: self.frame.width, height: 0)
        swiftuiView.frame = self.frame
        addEmbeddedLayoutConstraints(embeddedView: swiftuiView)

        vc.didMove(toParent: parentViewControllers)
    }

    public func closeEmbedded() {
        self.onSizeChange?(0)
        updateEmbeddedSize(0)
        roktEmbeddedSwiftUIView?.removeFromSuperview()
        roktEmbeddedSwiftUIView = nil
        RoktLogger.shared.info("User journey ended on Embedded view")
    }
}
