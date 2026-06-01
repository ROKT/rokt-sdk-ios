import SwiftUI
import DcuiSchema

@available(iOS 13, *)
struct BackgroundImageStyleModel: Decodable, Hashable {
    let url: ThemeUrl?
    let position: Position?
    let scale: ScaleStyleModel?
}

@available(iOS 13, *)
enum Position: String, Decodable, Hashable {
    case top
    case right
    case bottom
    case left
    case topRight = "top-right"
    case topLeft = "top-left"
    case bottomRight = "bottom-right"
    case bottomLeft = "bottom-left"
    case center

    func getAlignment() -> Alignment {
        switch self {
        case .top:
            return .top
        case .right:
            return .trailing
        case .bottom:
            return .bottom
        case .left:
            return .leading
        case .topRight:
            return .topTrailing
        case .topLeft:
            return .topLeading
        case .bottomRight:
            return .bottomTrailing
        case .bottomLeft:
            return .bottomLeading
        default:
            return .center
        }
    }
}

@available(iOS 13, *)
enum ScaleStyleModel: String, Decodable, Hashable {
    case `fill`
    case fit

    func getScale() -> ContentMode {
        switch self {
        case .fill:
            return .fill
        default:
            return .fit
        }
    }
}

@available(iOS 13, *)
extension BackgroundImagePosition {
    func getAlignment() -> Alignment {
        switch self {
        case .top:
            return .top
        case .right:
            return .trailing
        case .bottom:
            return .bottom
        case .left:
            return .leading
        case .topRight:
            return .topTrailing
        case .topLeft:
            return .topLeading
        case .bottomRight:
            return .bottomTrailing
        case .bottomLeft:
            return .bottomLeading
        default:
            return .center
        }
    }
}

@available(iOS 13, *)
extension BackgroundImageScale {
    func getScale() -> ContentMode {
        switch self {
        case .fill:
            return .fill
            // To support crop in separat ticket
        default:
            return .fit
        }
    }
}
