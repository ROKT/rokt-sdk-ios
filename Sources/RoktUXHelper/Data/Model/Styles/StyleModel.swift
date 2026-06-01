import SwiftUI

@available(iOS 13, *)
enum ImageScaleProperty: String, Codable, RoktUXCaseIterableDefaultLast {
    case fill
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
enum VerticalAlignmentProperty: String, Codable, RoktUXCaseIterableDefaultLast {
    case center
    case bottom = "flex-end"
    case top = "flex-start"

    func getAlignment() -> Alignment {
        switch self {
        case .bottom:
            return .bottom
        case .center:
            return .center
        default:
            return .top
        }
    }

    func getVerticalAlignment() -> VerticalAlignment {
        switch self {
        case .bottom:
            return .bottom
        case .center:
            return .center
        default:
            return .top
        }
    }
}

@available(iOS 13, *)
enum HorizontalAlignmentProperty: String, Codable, RoktUXCaseIterableDefaultLast {
    case end = "flex-end"
    case center
    case start = "flex-start"

    func getAlignment() -> Alignment {
        switch self {
        case .end:
            return .trailing
        case .center:
            return .center
        default:
            return .leading
        }
    }

    func getHorizontalAlignment() -> HorizontalAlignment {
        switch self {
        case .end:
            return .trailing
        case .center:
            return .center
        default:
            return .leading
        }
    }
}

@available(iOS 13, *)
enum HorizontalTextAlignmentProperty: String, Codable, RoktUXCaseIterableDefaultLast {
    case end = "flex-end"
    case center
    case start = "flex-start"

    func getTextAlignment() -> TextAlignment {
        switch self {
        case .end:
            return .trailing
        case .center:
            return .center
        default:
            return .leading
        }
    }

    func getAlignment() -> Alignment {
        switch self {
        case .end:
            return .trailing
        case .center:
            return .center
        default:
            return .leading
        }
    }

    var asHorizontalAlignmentProperty: HorizontalAlignmentProperty {
        switch self {
        case .end:
            return .end
        case .center:
            return .center
        default:
            return .start
        }
    }
}

@available(iOS 13, *)
extension VerticalAlignment {
    var asVerticalAlignmentProperty: VerticalAlignmentProperty {
        switch self {
        case .bottom:
            return .bottom
        case .center:
            return .center
        default:
            return .top
        }
    }
}

@available(iOS 13, *)
extension HorizontalAlignment {
    var asHorizontalAlignmentProperty: HorizontalAlignmentProperty {
        switch self {
        case .trailing:
            return .end
        case .center:
            return .center
        default:
            return .start
        }
    }
}

@available(iOS 13, *)
struct FrameAlignmentProperty: Equatable {
    let top: CGFloat
    let right: CGFloat
    let bottom: CGFloat
    let left: CGFloat

    static func getFrameAlignment(_ frameAlignment: String?) -> FrameAlignmentProperty {
        let defaultAlignment = FrameAlignmentProperty(top: 0, right: 0, bottom: 0, left: 0)

        guard let frameAlignment else { return defaultAlignment }

        let frameAlignmentValues = frameAlignment.split(separator: " ")

        var top: Float?
        var right: Float?
        var bottom: Float?
        var left: Float?
        if frameAlignmentValues.count == 4 {
            top = Float(frameAlignmentValues[0])
            right = Float(frameAlignmentValues[1])
            bottom = Float(frameAlignmentValues[2])
            left = Float(frameAlignmentValues[3])

        } else if frameAlignmentValues.count == 3 {
            top = Float(frameAlignmentValues[0])
            right = Float(frameAlignmentValues[1])
            bottom = Float(frameAlignmentValues[2])
            left = Float(frameAlignmentValues[1])

        } else if frameAlignmentValues.count == 2 {
            top = Float(frameAlignmentValues[0])
            right = Float(frameAlignmentValues[1])
            bottom = Float(frameAlignmentValues[0])
            left = Float(frameAlignmentValues[1])

        } else if frameAlignmentValues.count == 1 {
            top = Float(frameAlignmentValues[0])
            right = Float(frameAlignmentValues[0])
            bottom = Float(frameAlignmentValues[0])
            left = Float(frameAlignmentValues[0])

        } else {
            return defaultAlignment
        }

        return FrameAlignmentProperty(top: CGFloat(top ?? 0),
                                      right: CGFloat(right ?? 0),
                                      bottom: CGFloat(bottom ?? 0),
                                      left: CGFloat(left ?? 0))
    }

    func isMultiDimension() -> Bool {
        return !(top.isEqual(to: bottom) && top.isEqual(to: left) && top.isEqual(to: right))
    }

    func defaultWidth() -> CGFloat {
        return [top, bottom, left, right].min() ?? 0
    }

    static let zeroDimension = FrameAlignmentProperty(top: 0, right: 0, bottom: 0, left: 0)
}

@available(iOS 13, *)
internal extension FrameAlignmentProperty {
    var horizontalSpacing: CGFloat { self.right + self.left }
    var verticalSpacing: CGFloat { self.top + self.bottom }
}

@available(iOS 13, *)
struct OffsetProperty: Equatable {
    let x: CGFloat
    let y: CGFloat

    static func getOffset(_ offsetString: String?) -> OffsetProperty {
        let defaultOffset = OffsetProperty(x: 0, y: 0)

        guard let offsetString else { return defaultOffset }

        let offsetValues = offsetString.split(separator: " ")

        guard offsetValues.count == 2,
              let x = Float(offsetValues[0]),
              let y = Float(offsetValues[1])
        else {
            return defaultOffset
        }

        return OffsetProperty(x: CGFloat(x), y: CGFloat(y))
    }

    static let zeroOffset = OffsetProperty(x: 0, y: 0)
}
