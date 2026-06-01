import SwiftUI

@available(iOS 15, *)
class AttributedStringTransformer {

    static func convertRichTextHTMLIfExists(
        uiModel: LayoutSchemaViewModel,
        config: RoktUXConfig?,
        colorScheme: ColorScheme? = nil
    ) {
        switch uiModel {
        case .overlay(let parentModel):
            convertRichTextHTMLInChildren(parent: parentModel, config: config)
        case .bottomSheet(let parentModel):
            convertRichTextHTMLInChildren(parent: parentModel, config: config)
        case .row(let parentModel):
            convertRichTextHTMLInChildren(parent: parentModel, config: config)
        case .scrollableRow(let parentModel):
            convertRichTextHTMLInChildren(parent: parentModel, config: config)
        case .column(let parentModel):
            convertRichTextHTMLInChildren(parent: parentModel, config: config)
        case .scrollableColumn(let parentModel):
            convertRichTextHTMLInChildren(parent: parentModel, config: config)
        case .zStack(let parentModel):
            convertRichTextHTMLInChildren(parent: parentModel, config: config)
        case .oneByOne(let parentModel):
            convertRichTextHTMLInChildren(parent: parentModel, config: config)
        case .carousel(let parentModel):
            convertRichTextHTMLInChildren(parent: parentModel, config: config)
        case .progressControl(let parentModel):
            convertRichTextHTMLInChildren(parent: parentModel, config: config)
        case .groupDistribution(let parentModel):
            convertRichTextHTMLInChildren(parent: parentModel, config: config)
        case .when(let parentModel):
            convertRichTextHTMLInChildren(parent: parentModel, config: config)
        case .creativeResponse(let parentModel):
            convertRichTextHTMLInChildren(parent: parentModel, config: config)
        case .toggleButton(let parentModel):
            convertRichTextHTMLInChildren(parent: parentModel, config: config)
        case .catalogDevicePayButton(let parentModel):
            convertRichTextHTMLInChildren(parent: parentModel, config: config)
        case .catalogResponseButton(let parentModel):
            convertRichTextHTMLInChildren(parent: parentModel, config: config)
        case .catalogStackedCollection(let parentModel):
            convertRichTextHTMLInChildren(parent: parentModel, config: config)
        case .catalogCombinedCollection(let parentModel):
            convertRichTextHTMLInChildren(parent: parentModel, config: config)
        case .richText(let richTextUIModel):
            richTextUIModel.transformValueToAttributedString(config?.colorMode, colorScheme: nil)
        default:
            break
        }
    }

    static func convertRichTextHTMLInChildren(parent: DomainMappableParent, config: RoktUXConfig?) {
        guard let children = parent.children, !children.isEmpty else { return }

        children.forEach { convertRichTextHTMLIfExists(uiModel: $0, config: config) }
    }
}
