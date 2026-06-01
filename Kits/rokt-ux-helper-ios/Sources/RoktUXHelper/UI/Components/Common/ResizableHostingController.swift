import Foundation
import SwiftUI

@available(iOS 15, *)
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
