import SwiftUI
import DcuiSchema

@available(iOS 15, *)
struct HeightModifier {
    enum Constant {
        static let defaultAlignment = VerticalAlignment.top
    }

    let heightProperty: DimensionHeightValue?
    let minimum: Float?
    let maximum: Float?

    let alignment: Alignment?
    let defaultHeight: HeightFitProperty
    let alignmentAsVerticalType: VerticalAlignment

    let parentHeight: CGFloat?

    init(
        heightProperty: DimensionHeightValue?,
        minimum: Float?, maximum: Float?,
        alignment: Alignment?,
        defaultHeight: HeightFitProperty,
        parentHeight: CGFloat?
    ) {
        self.heightProperty = heightProperty
        self.minimum = minimum
        self.maximum = maximum
        self.alignment = alignment
        self.defaultHeight = defaultHeight
        self.parentHeight = parentHeight

        self.alignmentAsVerticalType = alignment?.asVerticalType ?? Constant.defaultAlignment
    }

    var fixedHeight: CGFloat? {
        if case .fixed(let value) = heightProperty {
            return CGFloat(value)
        } else {
            return nil
        }
    }

    var isFixedHeight: Bool { fixedHeight != nil }

    var isPercentageHeight: Bool {
        if case .percentage = heightProperty {
            return true
        } else {
            return false
        }
    }

    var maxHeight: CGFloat? {
        if let mHeight = maximum {
            return CGFloat(mHeight)
        } else if case .fit(let fitProperty) = heightProperty {
            if fitProperty == .fitHeight {
                return parentHeight
            } else {
                // when fit = wrap-content is explicitly set
                return nil
            }
        } else if defaultHeight == .fitHeight {
            return parentHeight
        } else {
            return nil
        }
    }

    var minHeight: CGFloat? {
        if let mHeight = minimum {
            return CGFloat(mHeight)
        } else if defaultHeight == .fitHeight {
            return .zero
        } else if case .fit(let fitProperty) = heightProperty, fitProperty == .fitHeight {
            return .zero
        } else {
            return nil
        }
    }

    // We maintain a hierarchy of modifiers. In order of priority
    // 1. if the value type is fixed, ignore min/max, ignore fit
    // 2. if the value type is percentage, respect min/max, ignore fit
    // 3. if neither fixed nor percentage is provided, use fit to set maxHeight
    //      3.a if fit = wrapContent, return the unmodified version of the content unless it has min/max height
    //      3.b if fit = fillHeight, set the content's maxHeight = infinity
    // 4. if fit doesn't exist and neither fixed or percentage was provided, use default. this default is set at component level
    //      4.a if fit = wrapContent, return the unmodified version of the content unless it has min/max height
    //      4.b if fit = fillHeight, set the content's maxHeight = infinity
    var frameMinHeight: CGFloat? {
        if let heightProperty {
            if isFixedHeight {
                return nil
            } else if isPercentageHeight {
                return minHeight
            } else if case .fit(let fitProperty) = heightProperty {
                if fitProperty == .fitHeight {
                    return nil
                } else { // fit = wrap-content
                    if minHeight != nil || maximum != nil {
                        return minHeight
                    } else {
                        return nil
                    }
                }
            } else {
                if minHeight != nil || maximum != nil {
                    return minHeight
                } else {
                    return nil
                }
            }
        } else {
            if defaultHeight == .fitHeight {
                return nil
            } else {
                if minHeight != nil || maximum != nil {
                    return minHeight
                } else {
                    return nil
                }
            }
        }
    }

    var frameMaxHeight: CGFloat? {
        if let heightProperty {
            if isFixedHeight {
                return nil
            } else if isPercentageHeight {
                return maxHeight
            } else if case .fit(let fitProperty) = heightProperty {
                if fitProperty == .fitHeight {
                    return parentHeight
                } else { // fit = wrap-content
                    if minHeight != nil || maximum != nil {
                        return maxHeight
                    } else {
                        return nil
                    }
                }
            } else {
                if minHeight != nil || maximum != nil {
                    return maxHeight
                } else {
                    return nil
                }
            }
        } else {
            if defaultHeight == .fitHeight {
                return parentHeight
            } else {
                if minHeight != nil || maximum != nil {
                    return maxHeight
                } else {
                    return nil
                }
            }
        }
    }
}
