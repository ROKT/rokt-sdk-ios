import Foundation
import DcuiSchema

@available(iOS 13, *)
struct SpacingStylingPropertiesModel: Decodable, Hashable {
    let padding: String?
    let margin: String?
    let offset: String?
}

@available(iOS 13, *)
protocol SpacingStyleable {
    var spacing: SpacingStylingProperties? { get }

    func getPadding() -> FrameAlignmentProperty
    func getMargin() -> FrameAlignmentProperty
    func getOffset() -> OffsetProperty
}

@available(iOS 13, *)
extension SpacingStyleable {
    func getPadding() -> FrameAlignmentProperty {
        guard let padding = spacing?.padding else { return FrameAlignmentProperty.zeroDimension }

        return FrameAlignmentProperty.getFrameAlignment(padding)
    }

    func getMargin() -> FrameAlignmentProperty {
        guard let margin = spacing?.margin else { return FrameAlignmentProperty.zeroDimension }

        return FrameAlignmentProperty.getFrameAlignment(margin)
    }

    func getOffset() -> OffsetProperty {
        guard let offsetString = spacing?.offset
        else {
            return OffsetProperty.zeroOffset
        }
        return OffsetProperty.getOffset(offsetString)
    }
}
