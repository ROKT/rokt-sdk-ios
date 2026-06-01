import SwiftUI
import DcuiSchema

@available(iOS 15, *)
struct WidthModifier {
    enum Constant {
        static let defaultAlignment = HorizontalAlignment.leading
    }

    let widthProperty: DimensionWidthValue?
    let minimum: Float?
    let maximum: Float?

    let alignment: Alignment?
    let defaultWidth: WidthFitProperty
    let alignmentAsHorizontalType: HorizontalAlignment

    let parentWidth: CGFloat?

    init(
        widthProperty: DimensionWidthValue?,
        minimum: Float?, maximum: Float?,
        alignment: Alignment?,
        defaultWidth: WidthFitProperty,
        parentWidth: CGFloat?
    ) {
        self.widthProperty = widthProperty
        self.minimum = minimum
        self.maximum = maximum
        self.alignment = alignment
        self.defaultWidth = defaultWidth
        self.parentWidth = parentWidth
        self.alignmentAsHorizontalType = alignment?.asHorizontalType ?? Constant.defaultAlignment
    }

    var fixedWidth: CGFloat? {
        if case .fixed(let value) = widthProperty {
            return CGFloat(value)
        } else {
            return nil
        }
    }

    var isFixedWidth: Bool { fixedWidth != nil }

    var isPercentageWidth: Bool {
        if case .percentage = widthProperty {
            return true
        } else {
            return false
        }
    }

    var maxWidth: CGFloat? {
        if let mWidth = maximum {
            return CGFloat(mWidth)
        } else if case .fit(let fitProperty) = widthProperty, fitProperty == .fitWidth {
            return parentWidth
        } else if case .fit(let fitProperty) = widthProperty, fitProperty == .wrapContent {
            return nil
        } else if defaultWidth == .fitWidth {
            return parentWidth
        }
        return nil
    }

    var minWidth: CGFloat? {
        if let mWidth = minimum {
            return CGFloat(mWidth)
        } else if case .fit(let fitProperty) = widthProperty, fitProperty == .fitWidth {
            return .zero
        } else {
            return nil
        }
    }

    // We maintain a hierarchy of modifiers. In order of priority
    // 1. if the value type is fixed, ignore min/max, ignore fit
    // 2. if the value type is percentage, respect min/max, ignore fit
    // 3. if neither fixed nor percentage is provided, use fit to set maxWidth
    //      3.a if fit = wrapContent, return the unmodified version of the content unless it has min/max width
    //      3.b if fit = fillWidth, set the content's maxWidth = infinity
    // 4. if fit doesn't exist and neither fixed or percentage was provided, use default. this default is set at component level
    //      4.a if fit = wrapContent, return the unmodified version of the content unless it has min/max width
    //      4.b if fit = fillWidth, set the content's maxWidth = infinity
    var frameMinWidth: CGFloat? {
        if let widthProperty {
            if isFixedWidth {
                return nil
            } else if isPercentageWidth {
                return minWidth
            } else if case .fit(let fitProperty) = widthProperty {
                if fitProperty == .fitWidth {
                    return nil
                } else { // fit = wrap-content
                    if minWidth != nil || maxWidth != nil {
                        return minWidth
                    } else {
                        return nil
                    }
                }
            } else {
                if minWidth != nil || maxWidth != nil {
                    return minWidth
                } else {
                    return nil
                }
            }
        } else {
            if defaultWidth == .fitWidth {
                return nil
            } else {
                if minWidth != nil || maxWidth != nil {
                    return minWidth
                } else {
                    return nil
                }
            }
        }
    }

    var frameMaxWidth: CGFloat? {
        if let widthProperty {
            if isFixedWidth {
                return nil
            } else if isPercentageWidth {
                return maxWidth
            } else if case .fit(let fitProperty) = widthProperty {
                if fitProperty == .fitWidth { // get all available space
                    return .infinity
                } else { // fit = wrap-content
                    if minWidth != nil || maxWidth != nil {
                        return maxWidth
                    } else {
                        return nil
                    }
                }
            } else {
                if minWidth != nil || maxWidth != nil {
                    return maxWidth
                } else {
                    return nil
                }
            }
        } else {
            if defaultWidth == .fitWidth {
                return parentWidth
            } else {
                if minWidth != nil || maxWidth != nil {
                    return maxWidth
                } else {
                    return nil
                }
            }
        }
    }
}
