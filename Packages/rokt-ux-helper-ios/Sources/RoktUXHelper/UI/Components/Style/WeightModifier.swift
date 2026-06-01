import SwiftUI
import DcuiSchema

@available(iOS 15, *)
struct WeightModifier {
    struct Properties {
        let weight: Float?
        let parent: ComponentParentType
        let verticalAlignment: Alignment
        let horizontalAlignment: Alignment
    }

    enum Constant {
        static let defaultVerticalAlignment = VerticalAlignment.top
        static let defaultHorizontalAlignment = HorizontalAlignment.leading
    }

    let props: Properties

    var weight: Float? {
        props.weight
    }
    var parent: ComponentParentType {
        props.parent
    }
    var verticalAlignment: Alignment {
        props.verticalAlignment
    }
    var horizontalAlignment: Alignment {
        props.horizontalAlignment
    }

    var alignment: Alignment {
        switch parent {
        case .row:
            return horizontalAlignment
        case .column:
            return verticalAlignment
        case .root:
            return horizontalAlignment
        }
    }

    var frameMaxHeight: CGFloat? {
        guard let weight, weight != 0 else {
            return nil
        }
        switch parent {
        case .column:
            return .infinity
        default:
            return nil
        }
    }

    var frameMaxWidth: CGFloat? {
        guard let weight, weight != 0 else {
            return nil
        }
        switch parent {
        case .row:
            return .infinity
        default:
            return nil
        }
    }
}
