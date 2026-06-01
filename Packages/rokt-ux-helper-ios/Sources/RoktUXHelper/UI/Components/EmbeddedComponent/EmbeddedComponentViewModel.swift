import SwiftUI

@available(iOS 15, *)
class EmbeddedComponentViewModel: ObservableObject {
    let layout: LayoutSchemaViewModel
    private let layoutState: LayoutState?
    private weak var eventService: EventServicing?
    private var onLoadCallback: (() -> Void)?
    private var onSizeChange: ((CGFloat) -> Void)?
    private var lastUpdatedHeight: CGFloat = 0

    init(
        layout: LayoutSchemaViewModel,
        layoutState: LayoutState?,
        eventService: EventServicing?,
        onLoad: (() -> Void)?, onSizeChange: ((CGFloat) -> Void)?
    ) {
        self.layout = layout
        self.layoutState = layoutState
        self.eventService = eventService
        self.onLoadCallback = onLoad
        self.onSizeChange = onSizeChange
    }

    func onLoad() {
        eventService?.sendEventsOnLoad()
        RoktUXLogger.shared.debug("Embedded view loaded")
        onLoadCallback?()
        layoutState?.actionCollection[.checkBoundingBox](nil)
    }

    func onFirstTouch() {
        eventService?.sendSignalActivationEvent()
    }

    func updateColorScheme(_ newColor: ColorScheme) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            AttributedStringTransformer.convertRichTextHTMLIfExists(
                uiModel: layout,
                config: layoutState?.config,
                colorScheme: newColor
            )
        }
    }

    func updateHeight(_ newHeight: CGFloat) {
        let roundedHeight = newHeight.rounded(.up)
        let roundedLastUpdatedHeight = lastUpdatedHeight.rounded(.up)
        if roundedLastUpdatedHeight != roundedHeight {
            onSizeChange?(newHeight)
            lastUpdatedHeight = newHeight
        }
    }
}
