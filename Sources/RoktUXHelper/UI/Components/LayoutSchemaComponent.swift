import SwiftUI

@available(iOS 15, *)
struct LayoutSchemaComponent: View {
    let config: ComponentConfig
    let layout: LayoutSchemaViewModel

    @Binding var parentWidth: CGFloat?
    @Binding var parentHeight: CGFloat?
    @Binding var styleState: StyleState

    let parentOverride: ComponentParentOverride?

    let expandsToContainerOnSelfAlign: Bool

    init(
        config: ComponentConfig,
        layout: LayoutSchemaViewModel,
        parentWidth: Binding<CGFloat?>,
        parentHeight: Binding<CGFloat?>,
        styleState: Binding<StyleState>,
        parentOverride: ComponentParentOverride? = nil,
        expandsToContainerOnSelfAlign: Bool = false
    ) {
        self.config = config
        self.layout = layout
        self._parentWidth = parentWidth
        self._parentHeight = parentHeight
        self._styleState = styleState
        self.parentOverride = parentOverride
        self.expandsToContainerOnSelfAlign = expandsToContainerOnSelfAlign
    }

    var body: some View {
        switch layout {
        case .richText(let textModel):
            RichTextComponent(config: config,
                              model: textModel,
                              parentWidth: $parentWidth,
                              parentHeight: $parentHeight,
                              parentOverride: parentOverride,
                              borderStyle: nil)
        case .basicText(let basicTextModel):
            BasicTextComponent(config: config,
                               model: basicTextModel,
                               parentWidth: $parentWidth,
                               parentHeight: $parentHeight,
                               styleState: $styleState,
                               parentOverride: parentOverride,
                               expandsToContainerOnSelfAlign: expandsToContainerOnSelfAlign)
        case .column(let columnModel):
            ColumnComponent(config: config,
                            model: columnModel,
                            parentWidth: $parentWidth,
                            parentHeight: $parentHeight,
                            styleState: $styleState,
                            parentOverride: parentOverride)
        case .row(let rowModel):
            RowComponent(config: config,
                         model: rowModel,
                         parentWidth: $parentWidth,
                         parentHeight: $parentHeight,
                         styleState: $styleState,
                         parentOverride: parentOverride)
        case .scrollableColumn(let columnModel):
            ScrollableColumnComponent(config: config,
                                      model: columnModel,
                                      parentWidth: $parentWidth,
                                      parentHeight: $parentHeight,
                                      styleState: $styleState,
                                      parentOverride: parentOverride)
        case .scrollableRow(let rowModel):
            ScrollableRowComponent(config: config,
                                   model: rowModel,
                                   parentWidth: $parentWidth,
                                   parentHeight: $parentHeight,
                                   styleState: $styleState,
                                   parentOverride: parentOverride)
        case .zStack(let zStackModel):
            ZStackComponent(config: config,
                            model: zStackModel,
                            parentWidth: $parentWidth,
                            parentHeight: $parentHeight,
                            styleState: $styleState,
                            parentOverride: parentOverride)
        case .creativeResponse(let creativeResponseModel):
            CreativeResponseComponent(config: config,
                                      model: creativeResponseModel,
                                      parentWidth: $parentWidth,
                                      parentHeight: $parentHeight,
                                      parentOverride: parentOverride)
        case .staticImage(let imageModel):
            StaticImageViewComponent(config: config,
                                     model: imageModel,
                                     parentWidth: $parentWidth,
                                     parentHeight: $parentHeight,
                                     styleState: $styleState,
                                     parentOverride: parentOverride,
                                     expandsToContainerOnSelfAlign: expandsToContainerOnSelfAlign)
        case .dataImage(let imageModel):
            DataImageViewComponent(config: config,
                                   model: imageModel,
                                   parentWidth: $parentWidth,
                                   parentHeight: $parentHeight,
                                   styleState: $styleState,
                                   parentOverride: parentOverride,
                                   expandsToContainerOnSelfAlign: expandsToContainerOnSelfAlign)
        case .progressIndicator(let progressIndicatorModel):
            ProgressIndicatorComponent(config: config,
                                       model: progressIndicatorModel,
                                       parentWidth: $parentWidth,
                                       parentHeight: $parentHeight,
                                       parentOverride: parentOverride)
        case .oneByOne(let oneByOneModel):
            OneByOneDistributionComponent(config: config,
                                          model: oneByOneModel,
                                          parentWidth: $parentWidth,
                                          parentHeight: $parentHeight,
                                          styleState: $styleState,
                                          parentOverride: parentOverride)
        case .carousel(let carouselModel):
            CarouselDistributionComponent(config: config,
                                          model: carouselModel,
                                          parentWidth: $parentWidth,
                                          parentHeight: $parentHeight,
                                          styleState: $styleState,
                                          parentOverride: parentOverride)
        case .groupDistribution(let groupedDistributionModel):
            GroupedDistributionComponent(config: config,
                                         model: groupedDistributionModel,
                                         parentWidth: $parentWidth,
                                         parentHeight: $parentHeight,
                                         styleState: $styleState,
                                         parentOverride: parentOverride)
        case .when(let whenModel):
            WhenComponent(config: config,
                          model: whenModel,
                          parentWidth: $parentWidth,
                          parentHeight: $parentHeight,
                          styleState: $styleState,
                          parentOverride: parentOverride)
        case .closeButton(let closeButtonModel):
            CloseButtonComponent(config: config,
                                 model: closeButtonModel,
                                 parentWidth: $parentWidth,
                                 parentHeight: $parentHeight,
                                 parentOverride: parentOverride)
        case .staticLink(let staticLinkModel):
            StaticLinkComponent(config: config,
                                model: staticLinkModel,
                                parentWidth: $parentWidth,
                                parentHeight: $parentHeight,
                                parentOverride: parentOverride)
        case .progressControl(let progressControlModel):
            ProgressControlComponent(config: config,
                                     model: progressControlModel,
                                     parentWidth: $parentWidth,
                                     parentHeight: $parentHeight,
                                     parentOverride: parentOverride)
        case .toggleButton(let toggleButtonModel):
            ToggleButtonComponent(config: config,
                                  model: toggleButtonModel,
                                  parentWidth: $parentWidth,
                                  parentHeight: $parentHeight,
                                  parentOverride: parentOverride)
        case .dataImageCarousel(let dataImageCarouselModel):
            DataImageCarouselComponent(config: config,
                                       model: dataImageCarouselModel,
                                       parentWidth: $parentWidth,
                                       parentHeight: $parentHeight,
                                       styleState: $styleState,
                                       parentOverride: parentOverride)
        case .catalogStackedCollection(let model):
            CatalogStackedCollectionComponent(
                config: config,
                model: model,
                parentWidth: $parentWidth,
                parentHeight: $parentHeight,
                styleState: $styleState,
                parentOverride: parentOverride
            )
        case .catalogCombinedCollection(let model):
            CatalogCombinedCollectionComponent(
                config: config,
                model: model,
                parentWidth: $parentWidth,
                parentHeight: $parentHeight,
                styleState: $styleState,
                parentOverride: parentOverride
            )
        case .catalogDevicePayButton(let model):
            CatalogDevicePayButtonComponent(
                config: config,
                model: model,
                parentWidth: $parentWidth,
                parentHeight: $parentHeight,
                parentOverride: parentOverride
            )
        case .catalogResponseButton(let model):
            CatalogResponseButtonComponent(
                config: config,
                model: model,
                parentWidth: $parentWidth,
                parentHeight: $parentHeight,
                parentOverride: parentOverride
            )
        case .catalogDropdown(let model):
            CatalogDropdownComponent(
                config: config,
                model: model,
                parentWidth: $parentWidth,
                parentHeight: $parentHeight,
                parentOverride: parentOverride
            )
        case .catalogImageGallery(let galleryModel):
            CatalogImageGalleryComponent(
                model: galleryModel,
                config: config,
                parentWidth: $parentWidth,
                parentHeight: $parentHeight,
                styleState: $styleState,
                parentOverride: parentOverride
            )
        default:
            EmptyView()
        }
    }
}
