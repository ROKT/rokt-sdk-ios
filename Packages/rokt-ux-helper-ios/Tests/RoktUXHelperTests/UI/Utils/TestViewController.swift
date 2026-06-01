import Foundation
import SwiftUI
@testable import RoktUXHelper

@available(iOS 15, *)
struct TestViewController {
    static func createVC(_ experienceResponse: String, 
                         location: String? = "Location1",
                         frame: CGRect = CGRect(x: 0, y: 0, width: 300, height: 500)) -> UIViewController {
        let roktView = RoktLayoutUIView(frame: frame)
        roktView.loadLayout(experienceResponse: experienceResponse, location: location) { _ in
        } onPlatformEvent: { _ in
        } onEmbeddedSizeChange: { _ in
        }
        
        // Create a TestViewController and add the view to it
        let testViewController = UIViewController()
        testViewController.view.backgroundColor = .white
        testViewController.view.addSubview(roktView)
        roktView.translatesAutoresizingMaskIntoConstraints = false
        
        // Center the roktView in the testViewController
        NSLayoutConstraint.activate([
            roktView.centerXAnchor.constraint(equalTo: testViewController.view.centerXAnchor),
            roktView.centerYAnchor.constraint(equalTo: testViewController.view.centerYAnchor),
            roktView.widthAnchor.constraint(equalToConstant: frame.width),
            roktView.heightAnchor.constraint(equalToConstant: frame.height)
        ])
        
        // Make sure the view controller's view has a size
        testViewController.view.frame = frame
        
        // Load the view hierarchy
        testViewController.loadViewIfNeeded()
        
        return testViewController
    }
    
}
