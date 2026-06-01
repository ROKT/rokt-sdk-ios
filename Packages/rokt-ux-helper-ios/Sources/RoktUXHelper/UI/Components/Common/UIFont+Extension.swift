import UIKit

extension UIFont {
    func including(symbolicTraits: UIFontDescriptor.SymbolicTraits) -> UIFont? {
        var currentTraits = self.fontDescriptor.symbolicTraits
        currentTraits.update(with: symbolicTraits)
        return withOnly(symbolicTraits: currentTraits)
    }

    private func withOnly(symbolicTraits: UIFontDescriptor.SymbolicTraits) -> UIFont? {
        guard let fontDescriptor = fontDescriptor.withSymbolicTraits(symbolicTraits) else { return nil }
        return .init(descriptor: fontDescriptor, size: pointSize)
    }
}
