import SwiftUI
import DcuiSchema

@available(iOS 13, *)
extension TextStylingProperties {
    private func asDistinctWeight(numericWeight: Int) -> FontWeightUIModel {
        switch numericWeight {
        case ...199: .thin
        case 200...299: .ultralight
        case 300...399: .light
        case 400...499: .normal
        case 500...599: .medium
        case 600...699: .semibold
        case 700...799: .bold
        case 800...899: .heavy
        case 900...: .black
        default: .normal
        }
    }

    var convertedWeight: FontWeightUIModel {
        guard let fontWeight, let nWeight = Int(fontWeight.rawValue) else { return .normal }

        return asDistinctWeight(numericWeight: nWeight)
    }

    var weightedUIFont: UIFont {
        // default to iOS default body font size
        // https://developer.apple.com/design/human-interface-guidelines/typography
        let fontSize = fontSize ?? 17
        let scaledSize = fontSize.getAsScaledFontSize()

        // default to SanFrancisco font
        var uiFont: UIFont = .systemFont(ofSize: CGFloat(scaledSize))

        if let fontFamily {
            if let customFont = UIFont(name: fontFamily, size: scaledSize) {
                // update if possible
                uiFont = customFont
            }
        }

        return uiFont.withWeight(convertedWeight.asUIFontWeight)
    }

    var styledFont: Font? {
        guard let fontStyle else { return Font(weightedUIFont) }

        switch fontStyle {
        case .italic: return Font(weightedUIFont.setItalic())
        default: return Font(weightedUIFont)
        }
    }

    var styledUIFont: UIFont? {
        guard let fontStyle else { return weightedUIFont }

        switch fontStyle {
        case .italic: return weightedUIFont.setItalic()
        default: return weightedUIFont
        }
    }

    var baselineOffset: CGFloat {
        guard let baselineTextAlign else { return 0 }

        switch baselineTextAlign {
        case .sub: return weightedUIFont.ascender * -0.5
        case .super: return weightedUIFont.ascender * 0.5
        case .baseline: return 0
        }
    }
}

enum FontWeightUIModel: String, Decodable {
    case thin
    case ultralight
    case light
    case normal
    case medium
    case semibold
    case bold
    case heavy
    case black

    // adapter pattern to map the platform-agnostic schema response
    // to Apple SDK's UIFont system
    var asUIFontWeight: UIFont.Weight {
        switch self {
        case .thin: return .thin
        case .ultralight: return .ultraLight
        case .light: return .light
        case .normal: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }
}

extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        var attributes = fontDescriptor.fontAttributes
        var traits = (attributes[.traits] as? [UIFontDescriptor.TraitKey: Any]) ?? [:]

        traits[.weight] = weight

        attributes[.name] = nil
        attributes[.traits] = traits
        attributes[.family] = familyName

        let descriptor = UIFontDescriptor(fontAttributes: attributes)

        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

extension UIFont {
    private var isItalic: Bool {
        fontDescriptor.symbolicTraits.contains(.traitItalic)
    }

    func setItalic() -> UIFont {
        guard !isItalic else { return self }

        var fontTraits = fontDescriptor.symbolicTraits
        fontTraits.insert(.traitItalic)

        guard let fontDescriptor = fontDescriptor.withSymbolicTraits(fontTraits) else { return self }

        return UIFont(descriptor: fontDescriptor, size: 0)
    }
}

extension FontWeight {
    var asUIFontWeight: UIFont.Weight {
        guard let asNumericWeight = Int(self.rawValue) else { return .regular }

        return asDistinctWeight(numericWeight: asNumericWeight).asUIFontWeight
    }

    private func asDistinctWeight(numericWeight: Int) -> FontWeightUIModel {
        switch numericWeight {
        case ...199: .thin
        case 200...299: .ultralight
        case 300...399: .light
        case 400...499: .normal
        case 500...599: .medium
        case 600...699: .semibold
        case 700...799: .bold
        case 800...899: .heavy
        case 900...: .black
        default: .normal
        }
    }
}

@available(iOS 13, *)
extension Float {
    func getAsScaledFontSize(contentSize: UIContentSizeCategory? = nil) -> CGFloat {
        guard let contentSize else {
            return UIFontMetrics.default.scaledValue(for: CGFloat(self))
        }
        return UIFontMetrics.default.scaledValue(for: CGFloat(self),
                                                 compatibleWith: .init(preferredContentSizeCategory: contentSize))
    }
}
