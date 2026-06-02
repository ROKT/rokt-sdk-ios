import Foundation
import SwiftUI
@testable import RoktUXHelper
import DcuiSchema

@available(iOS 15, *)
class MockLayoutSchemaViewModel: Identifiable, Hashable, ScreenSizeAdaptive {
    let id: UUID = UUID()
    var children: [LayoutSchemaViewModel]?
    let defaultStyle: [ColumnStyle]? // Using ColumnStyle as an example
    weak var layoutState: (any LayoutStateRepresenting)?

    var imageLoader: RoktUXImageLoader? {
        layoutState?.imageLoader
    }

    init(children: [LayoutSchemaViewModel]? = nil,
         defaultStyle: [ColumnStyle]? = nil,
         layoutState: any LayoutStateRepresenting = MockLayoutState()) {
        self.children = children
        self.defaultStyle = defaultStyle
        self.layoutState = layoutState
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: MockLayoutSchemaViewModel, rhs: MockLayoutSchemaViewModel) -> Bool {
        lhs.id == rhs.id
    }
}
