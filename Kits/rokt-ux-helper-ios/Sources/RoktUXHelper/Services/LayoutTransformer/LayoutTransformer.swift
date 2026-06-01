import Foundation
import DcuiSchema

struct LayoutTransformer<
    CreativeSyntaxMapper: SyntaxMapping,
    AddToCartMapper: SyntaxMapping,
    TransactionMapper: SyntaxMapping,
    Extractor: DataExtracting
>
where CreativeSyntaxMapper.Context == CreativeContext,
      AddToCartMapper.Context == CatalogItem,
      TransactionMapper.Context == TransactionData {

    enum Context {
        case outer([OfferModel?])
        case inner(Inner)

        enum Inner {
            case positive(OfferModel)
            case negative(OfferModel)
            case generic(OfferModel?)
            case addToCart(CatalogItem)
        }
    }

    let layoutPlugin: LayoutPlugin
    let layoutState: LayoutState
    let eventService: EventDiagnosticServicing?
    let creativeMapper: CreativeSyntaxMapper
    let addToCartMapper: AddToCartMapper
    let transactionDataMapper: TransactionMapper
    let extractor: Extractor

    var moduleName: String? {
        layoutPlugin.slots.first?.layoutVariant?.moduleName
    }

    init(
        layoutPlugin: LayoutPlugin,
        creativeMapper: CreativeSyntaxMapper = CreativeMapper(),
        addToCartMapper: AddToCartMapper = CatalogMapper(),
        transactionDataMapper: TransactionMapper = TransactionDataMapper(),
        extractor: Extractor = CreativeDataExtractor(),
        layoutState: LayoutState = LayoutState(),
        eventService: EventDiagnosticServicing? = nil
    ) {
        self.layoutPlugin = layoutPlugin
        self.creativeMapper = creativeMapper
        self.addToCartMapper = addToCartMapper
        self.transactionDataMapper = transactionDataMapper
        self.extractor = extractor
        self.layoutState = layoutState
        self.eventService = eventService
    }

    /// Pulls `transactionData` off the active offer (if any) so text mappers can resolve
    /// `%^DATA.transactionData.*^%` placeholders for order summaries / shipping cards.
    private var activeTransactionData: TransactionData? {
        (layoutState.items[LayoutState.fullOfferKey] as? OfferModel)?.transactionData
    }

    func transform() throws -> LayoutSchemaViewModel? {
        guard let layout = layoutPlugin.layout else { return nil}

        let transformedUIModels = try transform(
            layout,
            context: .outer(layoutPlugin.slots.map(\.offer))
        )

        AttributedStringTransformer.convertRichTextHTMLIfExists(uiModel: transformedUIModels, config: layoutState.config)

        return transformedUIModels
    }

    func transform<T: Codable>(_ layout: T, context: Context) throws -> LayoutSchemaViewModel {
        if let layout = layout as? LayoutSchemaModel {
            return try transform(layout, context: context)
        } else if let layout = layout as? AccessibilityGroupedLayoutChildren {
            return try transform(layout, context: context)
        } else {
            return .empty
        }
    }

    func transform(_ layout: LayoutSchemaModel, context: Context) throws -> LayoutSchemaViewModel {
        switch layout {
        case .row(let rowModel):
                .row(
                    try getRow(
                        rowModel.styles,
                        children: transformChildren(rowModel.children, context: context)
                    )
                )
        case .column(let columnModel):
                .column(
                    try getColumn(
                        columnModel.styles,
                        children: transformChildren(columnModel.children, context: context)
                    )
                )
        case .zStack(let zStackModel):
                .zStack(
                    try getZStack(
                        zStackModel.styles,
                        children: transformChildren(zStackModel.children, context: context)
                    )
                )
        case .basicText(let basicTextModel):
                .basicText(try getBasicText(basicTextModel, context: context))
        case .staticImage(let imageModel):
                .staticImage(try getStaticImage(imageModel))
        case .richText(let richTextModel):
                .richText(try getRichText(richTextModel, context: context))
        case .dataImage(let imageModel):
            try transformWithFallback {
                .dataImage(try getDataImage(imageModel, context: context))
            }
        case .progressIndicator(let progressIndicatorModel):
                .progressIndicator(try getProgressIndicatorUIModel(progressIndicatorModel, context: context))
        case .creativeResponse(let model):
            try getCreativeResponse(
                model: model,
                context: context
            )
        case .oneByOneDistribution(let oneByOneModel):
                .oneByOne(try getOneByOne(oneByOneModel: oneByOneModel, context: context))
        case .overlay(let overlayModel):
                .overlay(
                    try getOverlay(
                        overlayModel.styles,
                        allowBackdropToClose: overlayModel.allowBackdropToClose,
                        children: transformChildren(overlayModel.children, context: context)
                    )
                )
        case .bottomSheet(let bottomSheetModel):
                .bottomSheet(
                    try getBottomSheet(
                        bottomSheetModel.styles,
                        allowBackdropToClose: bottomSheetModel.allowBackdropToClose,
                        children: transformChildren(bottomSheetModel.children, context: context)
                    )
                )
        case .when(let whenModel):
                .when(
                    getWhenNode(
                        children: try transformChildren(whenModel.children, context: context),
                        predicates: whenModel.predicates,
                        transition: whenModel.transition
                    )
                )
        case .staticLink(let staticLinkModel):
                .staticLink(
                    try getStaticLink(
                        src: staticLinkModel.src,
                        open: staticLinkModel.open,
                        styles: staticLinkModel.styles,
                        children: transformChildren(staticLinkModel.children, context: context)
                    )
                )
        case .closeButton(let closeButtonModel):
                .closeButton(
                    try getCloseButton(
                        styles: closeButtonModel.styles,
                        children: transformChildren(closeButtonModel.children, context: context),
                        dismissalMethod: closeButtonModel.dismissalMethod
                    )
                )
        case .carouselDistribution(let carouselModel):
                .carousel(try getCarousel(carouselModel: carouselModel, context: context))
        case .groupedDistribution(let groupedModel):
                .groupDistribution(try getGroupedDistribution(groupedModel: groupedModel, context: context))
        case .progressControl(let progressControlModel):
                .progressControl(
                    try getProgressControl(
                        styles: progressControlModel.styles,
                        direction: progressControlModel.direction,
                        children: transformChildren(progressControlModel.children,
                                                    context: context)
                    )
                )
        case .accessibilityGrouped(let accessibilityGroupedModel):
            try getAccessibilityGrouped(
                child: accessibilityGroupedModel.child,
                context: context
            )
        case .scrollableColumn(let columnModel):
                .scrollableColumn(
                    try getScrollableColumn(
                        columnModel.styles,
                        children:
                            transformChildren(columnModel.children, context: context)
                    )
                )
        case .scrollableRow(let rowModel):
                .scrollableRow(
                    try getScrollableRow(
                        rowModel.styles,
                        children: transformChildren(rowModel.children, context: context)
                    )
                )
        case .toggleButtonStateTrigger(let buttonModel):
                .toggleButton(
                    try getToggleButton(
                        customStateKey: buttonModel.customStateKey,
                        styles: buttonModel.styles,
                        children: transformChildren(buttonModel.children,
                                                    context: context)
                    )
                )
        case .dataImageCarousel(let dataImageCarouselModel):
            try transformWithFallback {
                .dataImageCarousel(try getDataImageCarousel(dataImageCarouselModel, context: context))
            }
        case .catalogStackedCollection(let model):
                .catalogStackedCollection(
                    try getCatalogStackedCollectionModel(
                        model: model,
                        context: context
                    )
                )
        case .catalogResponseButton(let model):
                .catalogResponseButton(
                    try getCatalogResponseButtonModel(
                        style: model.styles,
                        children: transformChildren(model.children, context: context),
                        context: context
                    )
                )
        case .catalogDevicePayButton(let devicePayModel):
                .catalogDevicePayButton(
                    try getCatalogDevicePayButton(
                        model: devicePayModel,
                        children: transformChildren(devicePayModel.children, context: context),
                        context: context
                    )
                )
        case .catalogDropdown(let dropdownModel):
                .catalogDropdown(
                    try getCatalogDropdown(
                        model: dropdownModel,
                        attributeIndex: layoutState.nextCatalogDropdownAttributeIndex.advanceAndReturnPrevious()
                    )
                )
        case .catalogImageGallery(let galleryModel):
            try transformWithFallback {
                .catalogImageGallery(
                    try getCatalogImageGallery(model: galleryModel, context: context)
                )
            }
        case .catalogCombinedCollection(let model):
                .catalogCombinedCollection(
                    try getCatalogCombinedCollection(model: model, context: context)
                )
        }
    }

    func transform(
        _ layout: AccessibilityGroupedLayoutChildren,
        context: Context
    ) throws -> LayoutSchemaViewModel {
        switch layout {
        case .row(let rowModel):
                .row(try getRow(rowModel.styles, children: transformChildren(rowModel.children, context: context)))
        case .column(let columnModel):
            .column(
                try getColumn(
                    columnModel.styles,
                    children: transformChildren(columnModel.children, context: context)
                )
            )
        case .zStack(let zStackModel):
            .zStack(
                try getZStack(
                    zStackModel.styles,
                    children: transformChildren(zStackModel.children, context: context)
                )
            )
        }
    }

    func transformChildren<T: Codable>(_ layouts: [T]?, context: Context) throws -> [LayoutSchemaViewModel]? {
        try layouts?.map {
            try transform($0, context: context)
        }
    }

    // attach inner layout into outer layout and transform to UI Model
    func getOneByOne(oneByOneModel: OneByOneDistributionModel<WhenPredicate>, context: Context) throws -> OneByOneViewModel {
        let children: [LayoutSchemaViewModel] = try layoutPlugin.slots.compactMap {
            guard let innerLayout = $0.layoutVariant?.layoutVariantSchema else { return nil }
            return try transform(innerLayout, context: .inner(.generic($0.offer)))
        }
        let updateStyles = try StyleTransformer.updatedStyles(oneByOneModel.styles?.elements?.own)
        return OneByOneViewModel(children: children,
                                 defaultStyle: updateStyles.compactMap {$0.default},
                                 transition: oneByOneModel.transition,
                                 eventService: eventService,
                                 slots: layoutPlugin.slots,
                                 layoutState: layoutState)
    }

    func getCarousel(carouselModel: CarouselDistributionModel<WhenPredicate>, context: Context) throws -> CarouselViewModel {
        let children: [LayoutSchemaViewModel] = try layoutPlugin.slots.compactMap {
            guard let innerLayout = $0.layoutVariant?.layoutVariantSchema else { return nil }
            return try transform(innerLayout, context: .inner(.generic($0.offer)))
        }
        let updateStyles = try StyleTransformer.updatedStyles(carouselModel.styles?.elements?.own)
        return CarouselViewModel(children: children,
                                 defaultStyle: updateStyles.compactMap {$0.default},
                                 viewableItems: carouselModel.viewableItems,
                                 peekThroughSize: carouselModel.peekThroughSize,
                                 eventService: eventService,
                                 slots: layoutPlugin.slots,
                                 layoutState: layoutState)
    }

    func getGroupedDistribution(
        groupedModel: GroupedDistributionModel<WhenPredicate>,
        context: Context
    ) throws -> GroupedDistributionViewModel {
        let children: [LayoutSchemaViewModel] = try layoutPlugin.slots.compactMap {
            guard let innerLayout = $0.layoutVariant?.layoutVariantSchema else { return nil }
            return try transform(innerLayout, context: .inner(.generic($0.offer)))
        }
        let updateStyles = try StyleTransformer.updatedStyles(groupedModel.styles?.elements?.own)
        return GroupedDistributionViewModel(children: children,
                                            defaultStyle: updateStyles.compactMap {$0.default},
                                            viewableItems: groupedModel.viewableItems,
                                            transition: groupedModel.transition,
                                            eventService: eventService,
                                            slots: layoutPlugin.slots,
                                            layoutState: layoutState)
    }

    // MARK: Component Models

    func getStaticImage(_ imageModel: StaticImageModel<WhenPredicate>) throws -> StaticImageViewModel {
        let updatedStyles = try StyleTransformer.updatedStyles(imageModel.styles?.elements?.own, transform: BaseStyles.init)
        return StaticImageViewModel(url: imageModel.url,
                                    alt: imageModel.alt,
                                    stylingProperties: updatedStyles,
                                    layoutState: layoutState)
    }

    func getStaticLink(src: String,
                       open: LinkOpenTarget,
                       styles: LayoutStyle<StaticLinkElements,
                                           ConditionalStyleTransition<StaticLinkTransitions, WhenPredicate>>?,
                       children: [LayoutSchemaViewModel]?) throws -> StaticLinkViewModel {
        let updateStyles = try StyleTransformer.updatedStyles(styles?.elements?.own)
        return StaticLinkViewModel(children: children,
                                   src: src,
                                   open: open,
                                   defaultStyle: updateStyles.compactMap {$0.default},
                                   pressedStyle: updateStyles.compactMap {$0.pressed},
                                   hoveredStyle: updateStyles.compactMap {$0.hovered},
                                   disabledStyle: updateStyles.compactMap {$0.disabled},
                                   layoutState: layoutState,
                                   eventService: eventService)
    }

    func getCloseButton(styles: LayoutStyle<CloseButtonElements,
                                            ConditionalStyleTransition<CloseButtonTransitions, WhenPredicate>>?,
                        children: [LayoutSchemaViewModel]?,
                        dismissalMethod: String? = nil) throws -> CloseButtonViewModel {
        let updateStyles = try StyleTransformer.updatedStyles(styles?.elements?.own)
        return CloseButtonViewModel(children: children,
                                    defaultStyle: updateStyles.compactMap {$0.default},
                                    pressedStyle: updateStyles.compactMap {$0.pressed},
                                    hoveredStyle: updateStyles.compactMap {$0.hovered},
                                    disabledStyle: updateStyles.compactMap {$0.disabled},
                                    dismissalMethod: dismissalMethod,
                                    layoutState: layoutState,
                                    eventService: eventService)
    }

    func getCatalogDropdown(
        model: CatalogDropdownModel<WhenPredicate>,
        attributeIndex: Int = 0
    ) throws -> CatalogDropdownViewModel {
        let elements = model.styles?.elements
        let ownStyles = try StyleTransformer.updatedStyles(elements?.own)
        let headStyles = try StyleTransformer.updatedStyles(elements?.head)
        let iconStyles = try StyleTransformer.updatedStyles(elements?.icon)
        let optionListStyles = try StyleTransformer.updatedStyles(elements?.optionList)
        let optionStyles = try StyleTransformer.updatedStyles(elements?.option)
        let errorStyles = try StyleTransformer.updatedStyles(elements?.error)

        return CatalogDropdownViewModel(
            ownStyles: ownStyles.isEmpty ? nil : ownStyles,
            headStyles: headStyles.isEmpty ? nil : headStyles,
            iconStyles: iconStyles.isEmpty ? nil : iconStyles,
            optionListStyles: optionListStyles.isEmpty ? nil : optionListStyles,
            optionStyles: optionStyles.isEmpty ? nil : optionStyles,
            errorStyles: errorStyles.isEmpty ? nil : errorStyles,
            placeholderValue: model.placeholderValue,
            unavailableValue: model.unavailableValue,
            validatorFieldConfig: model.validatorFieldConfig,
            a11yLabel: model.a11yLabel,
            attributeIndex: attributeIndex,
            layoutState: layoutState,
            eventService: eventService
        )
    }

    func getCatalogImageGallery(
        model: CatalogImageGalleryModel<WhenPredicate>,
        context: Context
    ) throws -> CatalogImageGalleryViewModel {
        let elements = model.styles?.elements

        let ownStyles = try StyleTransformer.updatedStyles(elements?.own)
        let mainImageStyles = try StyleTransformer.updatedStyles(elements?.mainImage)
        let controlButtonStyles = try StyleTransformer.updatedStyles(elements?.controlButton)
        let indicatorStyles = try StyleTransformer.updatedStyles(elements?.indicator)
        let activeIndicatorStyles = try StyleTransformer.updatedStyles(elements?.activeIndicator)
        let seenIndicatorStyles = try StyleTransformer.updatedStyles(elements?.seenIndicator)
        let progressIndicatorContainer = try StyleTransformer.updatedStyles(elements?.progressIndicatorContainer)

        let imageDefaultStyle = mainImageStyles.compactMap { $0.default.asDataImageStyles }
        let imagePressedStyle = mainImageStyles.compactMap { $0.pressed?.asDataImageStyles }
        let imageHoveredStyle = mainImageStyles.compactMap { $0.hovered?.asDataImageStyles }
        let imageDisabledStyle = mainImageStyles.compactMap { $0.disabled?.asDataImageStyles }

        // Extract images from the catalog item in context
        var images: [DataImageViewModel] = []
        switch context {
        case let .inner(.addToCart(catalogItem)):
            images = catalogItem.images
                .sorted { $0.key < $1.key }
                .compactMap { DataImageViewModel(
                    image: $0.value,
                    defaultStyle: imageDefaultStyle.isEmpty ? nil : imageDefaultStyle,
                    pressedStyle: imagePressedStyle.isEmpty ? nil : imagePressedStyle,
                    hoveredStyle: imageHoveredStyle.isEmpty ? nil : imageHoveredStyle,
                    disabledStyle: imageDisabledStyle.isEmpty ? nil : imageDisabledStyle,
                    layoutState: layoutState
                ) }
        case .inner(.generic(let offer?)),
                .inner(.negative(let offer)),
                .inner(.positive(let offer)):
            if let catalogItem = offer.catalogItems?.first {
                images = catalogItem.images
                    .sorted { $0.key < $1.key }
                    .compactMap { DataImageViewModel(
                        image: $0.value,
                        defaultStyle: imageDefaultStyle.isEmpty ? nil : imageDefaultStyle,
                        pressedStyle: imagePressedStyle.isEmpty ? nil : imagePressedStyle,
                        hoveredStyle: imageHoveredStyle.isEmpty ? nil : imageHoveredStyle,
                        disabledStyle: imageDisabledStyle.isEmpty ? nil : imageDisabledStyle,
                        layoutState: layoutState
                    ) }
            }
        default:
            break
        }

        return CatalogImageGalleryViewModel(
            images: images,
            defaultStyle: ownStyles.compactMap { $0.default },
            mainImageStyles: mainImageStyles.isEmpty ? nil : mainImageStyles,
            controlButtonStyles: controlButtonStyles.isEmpty ? nil : controlButtonStyles,
            indicatorStyle: indicatorStyles.isEmpty ? nil : indicatorStyles,
            activeIndicatorStyle: activeIndicatorStyles.isEmpty ? nil : activeIndicatorStyles,
            seenIndicatorStyle: seenIndicatorStyles.isEmpty ? nil : seenIndicatorStyles,
            progressIndicatorContainer: progressIndicatorContainer.isEmpty ? nil : progressIndicatorContainer,
            showIndicators: model.showIndicators ?? true,
            backwardImage: model.backwardImage,
            forwardImage: model.forwardImage,
            a11yLabel: model.a11yLabel,
            layoutState: layoutState,
            eventService: eventService
        )
    }

    func getCatalogCombinedCollection(
        model: CatalogCombinedCollectionModel<CatalogCombinedCollectionLayoutSchemaTemplateNode, WhenPredicate>,
        context: Context
    ) throws -> CatalogCombinedCollectionViewModel {
        guard case let .inner(.generic(.some(offer))) = context else {
            throw LayoutTransformerError.InvalidMapping()
        }

        // Reset dropdown attribute counter for this offer's scope
        layoutState.nextCatalogDropdownAttributeIndex = 0

        // Set the first catalog item as active and store the full offer
        if let firstCatalogItem = offer.catalogItems?.first {
            layoutState.items[LayoutState.activeCatalogItemKey] = firstCatalogItem
        }
        layoutState.items[LayoutState.fullOfferKey] = offer

        let updateStyles = try StyleTransformer.updatedStyles(model.styles?.elements?.own)

        let childBuilder: (CatalogItem) -> [LayoutSchemaViewModel]? = { catalogItem in
            // Reset counter so dropdowns inside the template get consistent indices across rebuilds
            self.layoutState.nextCatalogDropdownAttributeIndex = 0
            do {
                switch model.template {
                case .column(let templateModel):
                    let transformedChildren = try self.transformChildren(
                        templateModel.children,
                        context: .inner(.addToCart(catalogItem))
                    )
                    return [
                        .column(
                            try self.getColumn(
                                templateModel.styles,
                                children: transformedChildren
                            )
                        )
                    ]
                case .row(let templateModel):
                    let transformedChildren = try self.transformChildren(
                        templateModel.children,
                        context: .inner(.addToCart(catalogItem))
                    )
                    return [
                        .row(
                            try self.getRow(
                                templateModel.styles,
                                children: transformedChildren
                            )
                        )
                    ]
                }
            } catch {
                return nil
            }
        }

        let initialChildren = offer.catalogItems?.first.flatMap(childBuilder) ?? []

        return CatalogCombinedCollectionViewModel(
            children: initialChildren,
            defaultStyle: updateStyles.compactMap { $0.default },
            layoutState: layoutState,
            eventService: eventService,
            childBuilder: childBuilder
        )
    }

    func getCatalogDevicePayButton(
        model: CatalogDevicePayButtonModel<LayoutSchemaModel, WhenPredicate>,
        children: [LayoutSchemaViewModel]?,
        context: Context
    ) throws -> CatalogDevicePayButtonViewModel {
        guard case let .inner(.addToCart(catalogItem)) = context else {
            throw LayoutTransformerError.InvalidMapping()
        }

        let transactionData = (layoutState.items[LayoutState.fullOfferKey] as? OfferModel)?.transactionData
        let updateStyles = try StyleTransformer.updatedStyles(model.styles?.elements?.own)
        return CatalogDevicePayButtonViewModel(
            catalogItem: catalogItem,
            children: children,
            provider: model.provider,
            layoutState: layoutState,
            eventService: eventService,
            defaultStyle: updateStyles.compactMap { $0.default },
            pressedStyle: updateStyles.compactMap { $0.pressed },
            hoveredStyle: updateStyles.compactMap { $0.hovered },
            disabledStyle: updateStyles.compactMap { $0.disabled },
            validatorTriggerConfig: model.validatorTriggerConfig,
            transactionData: transactionData
        )
    }

    func getProgressControl(styles: LayoutStyle<ProgressControlElements,
                                                ConditionalStyleTransition<ProgressControlTransitions, WhenPredicate>>?,
                            direction: ProgressionDirection,
                            children: [LayoutSchemaViewModel]?) throws -> ProgressControlViewModel {
        let updateStyles = try StyleTransformer.updatedStyles(styles?.elements?.own)
        return ProgressControlViewModel(children: children,
                                        defaultStyle: updateStyles.compactMap {$0.default},
                                        pressedStyle: updateStyles.compactMap {$0.pressed},
                                        hoveredStyle: updateStyles.compactMap {$0.hovered},
                                        disabledStyle: updateStyles.compactMap {$0.disabled},
                                        direction: direction,
                                        layoutState: layoutState)
    }

    func getDataImage(_ imageModel: DataImageModel<WhenPredicate>, context: Context) throws -> DataImageViewModel {
        var creativeImage: CreativeImage?
        switch context {
        case .inner(.generic(.some(let offer))),
                .inner(.negative(let offer)),
                .inner(.positive(let offer)):
            creativeImage = findImage(for: imageModel.imageKey, in: offer.creative.images)
        case let .inner(.addToCart(catalogItem)):
            creativeImage = findImage(for: imageModel.imageKey, in: catalogItem.images)
        default:
            throw LayoutTransformerError.missingData
        }
        let updateStyles = try StyleTransformer.updatedStyles(imageModel.styles?.elements?.own)
        return DataImageViewModel(image: creativeImage,
                                  defaultStyle: updateStyles.compactMap {$0.default},
                                  pressedStyle: updateStyles.compactMap {$0.pressed},
                                  hoveredStyle: updateStyles.compactMap {$0.hovered},
                                  disabledStyle: updateStyles.compactMap {$0.disabled},
                                  layoutState: layoutState)
    }

    func getBasicText(_ basicTextModel: BasicTextModel<WhenPredicate>, context: Context) throws -> BasicTextViewModel {
        let updateStyles = try StyleTransformer.updatedStyles(basicTextModel.styles?.elements?.own)
        let vm = BasicTextViewModel(value: basicTextModel.value,
                                    defaultStyle: updateStyles.compactMap {$0.default},
                                    pressedStyle: updateStyles.compactMap {$0.pressed},
                                    hoveredStyle: updateStyles.compactMap {$0.hovered},
                                    disabledStyle: updateStyles.compactMap {$0.disabled},
                                    layoutState: layoutState,
                                    diagnosticService: eventService)
        if case .inner = context, let bnfContext = context.mapToCreativeContext {
            creativeMapper.map(consumer: .basicText(vm), context: bnfContext)
        } else if case let .inner(.addToCart(catalogItem)) = context {
            addToCartMapper.map(consumer: .basicText(vm), context: catalogItem)
        }
        if case .inner = context, let transactionData = activeTransactionData {
            transactionDataMapper.map(consumer: .basicText(vm), context: transactionData)
        }
        // Final pass after the whole mapper chain: substitute `|` defaults for any
        // placeholder no mapper resolved, or zero the line if a mandatory orphan remains.
        vm.finalizePlaceholders()
        return vm
    }

    func getRichText(_ richTextModel: RichTextModel<WhenPredicate>, context: Context) throws -> RichTextViewModel {
        let updateStyles = try StyleTransformer.updatedStyles(richTextModel.styles?.elements?.own)
        let updateLinkStyles = try StyleTransformer.updatedStyles(richTextModel.styles?.elements?.link)
        let vm = RichTextViewModel(value: richTextModel.value,
                                   defaultStyle: updateStyles.compactMap {$0.default},
                                   linkStyle: updateLinkStyles.compactMap {$0.default},
                                   openLinks: richTextModel.openLinks,
                                   layoutState: layoutState,
                                   eventService: eventService)

        if case .inner = context, let bnfContext = context.mapToCreativeContext {
            creativeMapper.map(consumer: .richText(vm), context: bnfContext)
        } else if case let .inner(.addToCart(catalogItem)) = context {
            addToCartMapper.map(consumer: .richText(vm), context: catalogItem)
        }
        if case .inner = context, let transactionData = activeTransactionData {
            transactionDataMapper.map(consumer: .richText(vm), context: transactionData)
        }
        vm.finalizePlaceholders()
        return vm
    }

    func getColumn(_ styles: LayoutStyle<ColumnElements, ConditionalStyleTransition<ColumnTransitions, WhenPredicate>>?,
                   children: [LayoutSchemaViewModel]?,
                   accessibilityGrouped: Bool = false) throws -> ColumnViewModel {
        let updateStyles = try StyleTransformer.updatedStyles(styles?.elements?.own)
        return ColumnViewModel(children: children,
                               defaultStyle: updateStyles.compactMap {$0.default},
                               pressedStyle: updateStyles.compactMap {$0.pressed},
                               hoveredStyle: updateStyles.compactMap {$0.hovered},
                               disabledStyle: updateStyles.compactMap {$0.disabled},
                               accessibilityGrouped: accessibilityGrouped,
                               layoutState: layoutState)
    }

    func getScrollableColumn(_ styles: LayoutStyle<ScrollableColumnElements,
                                                   ConditionalStyleTransition<ScrollableColumnTransitions, WhenPredicate>>?,
                             children: [LayoutSchemaViewModel]?,
                             accessibilityGrouped: Bool = false) throws -> ColumnViewModel {
        let updateStyles = try StyleTransformer.updatedStyles(styles?.elements?.own)
        return ColumnViewModel(children: children,
                               defaultStyle: updateStyles.compactMap {
            StyleTransformer.convertToColumnStyles($0.default)
        },
                               pressedStyle: updateStyles.compactMap {
            StyleTransformer.convertToColumnStyles($0.pressed)
        },
                               hoveredStyle: updateStyles.compactMap {
            StyleTransformer.convertToColumnStyles($0.hovered)
        },
                               disabledStyle: updateStyles.compactMap {
            StyleTransformer.convertToColumnStyles($0.disabled)
        },
                               accessibilityGrouped: accessibilityGrouped,
                               layoutState: layoutState)
    }

    func getRow(_ styles: LayoutStyle<RowElements, ConditionalStyleTransition<RowTransitions, WhenPredicate>>?,
                children: [LayoutSchemaViewModel]?,
                accessibilityGrouped: Bool = false) throws -> RowViewModel {
        let updatedStyles = try StyleTransformer.updatedStyles(styles?.elements?.own, transform: BaseStyles.init)

        return RowViewModel(
            children: children,
            stylingProperties: updatedStyles,
            animatableStyle: AnimationStyle(
                transition: styles?.conditionalTransitions,
                transform: { $0.own.map(BaseStyles.init) }
            ),
            accessibilityGrouped: accessibilityGrouped,
            layoutState: layoutState,
            predicates: styles?.conditionalTransitions?.predicates,
            globalBreakPoints: layoutPlugin.breakpoints,
            offers: layoutPlugin.slots.map(\.offer)
        )
    }

    func getScrollableRow(_ styles: LayoutStyle<ScrollableRowElements,
                                                ConditionalStyleTransition<ScrollableRowTransitions, WhenPredicate>>?,
                          children: [LayoutSchemaViewModel]?,
                          accessibilityGrouped: Bool = false) throws -> RowViewModel {
        let updatedStyles = try StyleTransformer.updatedStyles(styles?.elements?.own, transform: BaseStyles.init)

        return RowViewModel(
            children: children,
            stylingProperties: updatedStyles,
            animatableStyle: AnimationStyle(
                transition: styles?.conditionalTransitions,
                transform: { $0.own.map(BaseStyles.init) }
            ),
            accessibilityGrouped: accessibilityGrouped,
            layoutState: layoutState,
            predicates: styles?.conditionalTransitions?.predicates,
            globalBreakPoints: layoutPlugin.breakpoints,
            offers: layoutPlugin.slots.map(\.offer)
        )
    }

    func getZStack(_ styles: LayoutStyle<ZStackElements, ConditionalStyleTransition<ZStackTransitions, WhenPredicate>>?,
                   children: [LayoutSchemaViewModel]?,
                   accessibilityGrouped: Bool = false) throws -> ZStackViewModel {
        let updateStyles = try StyleTransformer.updatedStyles(styles?.elements?.own)
        return ZStackViewModel(children: children,
                               defaultStyle: updateStyles.compactMap {$0.default},
                               pressedStyle: updateStyles.compactMap {$0.pressed},
                               hoveredStyle: updateStyles.compactMap {$0.hovered},
                               disabledStyle: updateStyles.compactMap {$0.disabled},
                               accessibilityGrouped: accessibilityGrouped,
                               layoutState: layoutState)
    }

    func getAccessibilityGrouped(child: AccessibilityGroupedLayoutChildren,
                                 context: Context) throws -> LayoutSchemaViewModel {
        switch child {
        case .column(let columnModel):
            return .column(try getColumn(columnModel.styles,
                                         children: transformChildren(columnModel.children, context: context),
                                         accessibilityGrouped: true))
        case .row(let rowModel):
            return .row(try getRow(rowModel.styles,
                                   children: transformChildren(rowModel.children, context: context),
                                   accessibilityGrouped: true))
        case .zStack(let zStackModel):
            return .zStack(try getZStack(zStackModel.styles,
                                         children: transformChildren(zStackModel.children, context: context),
                                         accessibilityGrouped: true))
        }
    }

    func getOverlay(_ styles: LayoutStyle<OverlayElements,
                                          ConditionalStyleTransition<OverlayTransitions, WhenPredicate>>?,
                    allowBackdropToClose: Bool?,
                    children: [LayoutSchemaViewModel]?) throws -> OverlayViewModel {
        let updateStyles = try StyleTransformer.updatedStyles(styles?.elements?.own)
        let updateWrapperStyles = try StyleTransformer.updatedStyles(styles?.elements?.wrapper)
        return OverlayViewModel(children: children,
                                allowBackdropToClose: allowBackdropToClose,
                                defaultStyle: updateStyles.compactMap {$0.default},
                                wrapperStyle: updateWrapperStyles.compactMap {$0.default},
                                eventService: eventService,
                                layoutState: layoutState)
    }

    func getBottomSheet(_ styles: LayoutStyle<BottomSheetElements,
                                              ConditionalStyleTransition<BottomSheetTransitions, WhenPredicate>>?,
                        allowBackdropToClose: Bool?,
                        children: [LayoutSchemaViewModel]?) throws -> BottomSheetViewModel {
        let updateStyles = try StyleTransformer.updatedStyles(styles?.elements?.own)
        return BottomSheetViewModel(children: children,
                                    allowBackdropToClose: allowBackdropToClose,
                                    defaultStyle: updateStyles.compactMap {$0.default},
                                    eventService: eventService,
                                    layoutState: layoutState)
    }

    func getCreativeResponse(model: CreativeResponseModel<LayoutSchemaModel, WhenPredicate>,
                             context: Context) throws -> LayoutSchemaViewModel {
        guard case let .inner(.generic(offer)) = context, let offer else {
            throw LayoutTransformerError.InvalidMapping()
        }
        var updatedContext: Context
        if model.responseKey == BNFNamespace.CreativeResponseKey.positive.rawValue,
           offer.creative.responseOptionsMap?.positive != nil {
            updatedContext = .inner(.positive(offer))
        } else if model.responseKey == BNFNamespace.CreativeResponseKey.negative.rawValue,
                  offer.creative.responseOptionsMap?.negative != nil {
            updatedContext = .inner(.negative(offer))
        } else {
            return .empty
        }
        let children = try transformChildren(model.children, context: updatedContext)
        return .creativeResponse(try getCreativeResponseUIModel(responseKey: model.responseKey,
                                                                openLinks: model.openLinks,
                                                                styles: model.styles,
                                                                children: children,
                                                                offer: offer))
    }

    func getCreativeResponseUIModel(
        responseKey: String,
        openLinks: LinkOpenTarget?,
        styles: LayoutStyle<CreativeResponseElements,
                            ConditionalStyleTransition<CreativeResponseTransitions, WhenPredicate>>?,
        children: [LayoutSchemaViewModel]?,
        offer: OfferModel
    ) throws -> CreativeResponseViewModel {
        var responseOption: RoktUXResponseOption?
        var creativeResponseKey = BNFNamespace.CreativeResponseKey.positive

        if responseKey == BNFNamespace.CreativeResponseKey.positive.rawValue {
            responseOption = offer.creative.responseOptionsMap?.positive
            creativeResponseKey = .positive
        }

        if responseKey == BNFNamespace.CreativeResponseKey.negative.rawValue {
            responseOption = offer.creative.responseOptionsMap?.negative
            creativeResponseKey = .negative
        }
        let updateStyles = try StyleTransformer.updatedStyles(styles?.elements?.own)
        return CreativeResponseViewModel(children: children,
                                         responseKey: creativeResponseKey,
                                         responseOptions: responseOption,
                                         openLinks: openLinks,
                                         layoutState: layoutState,
                                         eventService: eventService,
                                         defaultStyle: updateStyles.compactMap {$0.default},
                                         pressedStyle: updateStyles.compactMap {$0.pressed},
                                         hoveredStyle: updateStyles.compactMap {$0.hovered},
                                         disabledStyle: updateStyles.compactMap {$0.disabled})
    }

    private func getCatalogStackedCollectionModel(
        model: CatalogStackedCollectionModel<CatalogStackedCollectionLayoutSchemaTemplateNode, WhenPredicate>,
        context: Context,
        accessibilityGrouped: Bool = false
    ) throws -> CatalogStackedCollectionViewModel {
        guard case let .inner(.generic(.some(offer))) = context else {
            throw LayoutTransformerError.InvalidMapping()
        }

        let updateStyles = try StyleTransformer.updatedStyles(model.styles?.elements?.own)
        let children: [LayoutSchemaViewModel]? = try offer.catalogItems?.map { catalogItem in
            switch model.template {
            case .column(let model):
                return .column(
                    try getColumn(
                        model.styles,
                        children: transformChildren(
                            model.children,
                            context: .inner(.addToCart(catalogItem))
                        )
                    )
                )
            case .row(let model):
                return .row(
                    try getRow(
                        model.styles,
                        children: transformChildren(
                            model.children,
                            context: .inner(.addToCart(catalogItem))
                        )
                    )
                )
            }
        }
        return CatalogStackedCollectionViewModel(
            children: children,
            defaultStyle: updateStyles.compactMap {$0.default},
            layoutState: layoutState
        )
    }

    func getCatalogResponseButtonModel(
        style: LayoutStyle<
            CatalogResponseButtonElements,
            ConditionalStyleTransition<CatalogResponseButtonTransitions, WhenPredicate>
        >?,
        children: [LayoutSchemaViewModel]?,
        context: Context
    ) throws -> CatalogResponseButtonViewModel {
        guard case let .inner(.addToCart(catalogItem)) = context else {
            throw LayoutTransformerError.InvalidMapping()
        }

        let transactionData = (layoutState.items[LayoutState.fullOfferKey] as? OfferModel)?.transactionData
        let updateStyles = try StyleTransformer.updatedStyles(style?.elements?.own)
        return CatalogResponseButtonViewModel(
            catalogItem: catalogItem,
            children: children,
            layoutState: layoutState,
            eventService: eventService,
            defaultStyle: updateStyles.compactMap { $0.default },
            pressedStyle: updateStyles.compactMap { $0.pressed },
            hoveredStyle: updateStyles.compactMap { $0.hovered },
            disabledStyle: updateStyles.compactMap { $0.disabled },
            transactionData: transactionData
        )
    }

    func getProgressIndicatorUIModel(
        _ progressIndicatorModel: ProgressIndicatorModel<WhenPredicate>,
        context: Context
    ) throws -> ProgressIndicatorViewModel {
        let updateStyles = try StyleTransformer.updatedStyles(progressIndicatorModel.styles?.elements?.own)
        let indicatorStyle = try StyleTransformer.updatedStyles(progressIndicatorModel.styles?.elements?.indicator)
        let seenIndicatorStyle = try StyleTransformer.updatedIndicatorStyles(
            indicatorStyle,
            newStyles: progressIndicatorModel.styles?.elements?.seenIndicator
        )
        // active falls back to seen (which then falls back to indicator)
        let activeIndicatorStyle = try StyleTransformer.updatedIndicatorStyles(
            seenIndicatorStyle,
            newStyles: progressIndicatorModel.styles?.elements?.activeIndicator
        )
        let vm = ProgressIndicatorViewModel(
            indicator: progressIndicatorModel.indicator,
            defaultStyle: updateStyles.compactMap {$0.default},
            indicatorStyle: indicatorStyle.compactMap {$0.default},
            activeIndicatorStyle: activeIndicatorStyle.compactMap {$0.default},
            seenIndicatorStyle: seenIndicatorStyle.compactMap {$0.default},
            startPosition: progressIndicatorModel.startPosition,
            accessibilityHidden: progressIndicatorModel.accessibilityHidden,
            layoutState: layoutState,
            eventService: eventService
        )
        if let bnfContext = context.mapToCreativeContext {
            creativeMapper.map(consumer: .progressIndicator(vm), context: bnfContext)
        } else if case let .inner(.addToCart(catalogItem)) = context {
            addToCartMapper.map(consumer: .progressIndicator(vm), context: catalogItem)
        }
        return vm
    }

    func getWhenNode(children: [LayoutSchemaViewModel]?,
                     predicates: [WhenPredicate],
                     transition: WhenTransition?) -> WhenViewModel {
        return WhenViewModel(children: children,
                             predicates: predicates,
                             transition: transition,
                             offers: layoutPlugin.slots.map(\.offer),
                             globalBreakPoints: layoutPlugin.breakpoints,
                             layoutState: layoutState)
    }

    func getToggleButton(customStateKey: String,
                         styles: LayoutStyle<ToggleButtonStateTriggerElements,
                                             ConditionalStyleTransition<ToggleButtonStateTriggerTransitions, WhenPredicate>>?,
                         children: [LayoutSchemaViewModel]?) throws -> ToggleButtonViewModel {
        let updateStyles = try StyleTransformer.updatedStyles(styles?.elements?.own)
        return ToggleButtonViewModel(children: children,
                                     customStateKey: customStateKey,
                                     defaultStyle: updateStyles.compactMap {$0.default},
                                     pressedStyle: updateStyles.compactMap {$0.pressed},
                                     hoveredStyle: updateStyles.compactMap {$0.hovered},
                                     disabledStyle: updateStyles.compactMap {$0.disabled},
                                     layoutState: layoutState)
    }

    func getDataImageCarousel(_ dataImageCarouselModel: DataImageCarouselModel<WhenPredicate>,
                              context: Context) throws -> DataImageCarouselViewModel {
        var carouselImages: [CreativeImage]?
        switch context {
        case .inner(.generic(let offer?)),
                .inner(.negative(let offer)),
                .inner(.positive(let offer)):
            let imageKeys = dataImageCarouselModel.imageKey.split(separator: "|").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            carouselImages = offer.creative.images?.filter { image in
                imageKeys.contains { key in
                    image.key.contains(key)
                }
            }
            .sorted(by: { $0.key < $1.key })
            .compactMap { $0.value }
        default:
            throw LayoutTransformerError.InvalidMapping()
        }
        guard let carouselImages else { throw LayoutTransformerError.missingData }

        let ownStyle = try StyleTransformer.updatedStyles(dataImageCarouselModel.styles?.elements?.own)

        let indicatorStyle = try StyleTransformer.updatedStyles(dataImageCarouselModel.indicatorStyles)
        let seenIndicatorStyle = try StyleTransformer.updatedIndicatorStyles(
            indicatorStyle,
            newStyles: dataImageCarouselModel.seenIndicatorStyles
        )

        // active falls back to seen (which then falls back to indicator)
        let activeIndicatorStyle = try StyleTransformer.updatedIndicatorStyles(
            seenIndicatorStyle,
            newStyles: dataImageCarouselModel.activeIndicatorStyles
        )

        let indicatorContainerStyle = try StyleTransformer
            .updatedStyles(dataImageCarouselModel.progressIndicatorContainerStyles)

        let transition = dataImageCarouselModel.transition ?? .fadeInOut(.init(speed: .medium))
        let indicators = dataImageCarouselModel.indicators ?? .init(show: true, activeIndicatorMode: .timer)

        let indicatorViewModel: ImageCarouselIndicatorViewModel?
        if indicators.show ?? true {
            indicatorViewModel = ImageCarouselIndicatorViewModel(
                positions: carouselImages.count,
                duration: dataImageCarouselModel.duration,
                stylingProperties: indicatorContainerStyle,
                indicatorStyle: indicatorStyle,
                seenIndicatorStyle: seenIndicatorStyle,
                activeIndicatorStyle: activeIndicatorStyle,
                layoutState: layoutState,
                shouldDisplayProgress: dataImageCarouselModel.indicators?.shouldShowProgress ?? true
            )
        } else {
            indicatorViewModel = nil
        }

        return DataImageCarouselViewModel(key: dataImageCarouselModel.imageKey,
                                          images: carouselImages,
                                          duration: dataImageCarouselModel.duration,
                                          ownStyle: ownStyle,
                                          indicatorViewModel: indicatorViewModel,
                                          layoutState: layoutState,
                                          transition: transition.transtion)
    }

    private func transformWithFallback(_ transform: () throws -> LayoutSchemaViewModel) throws -> LayoutSchemaViewModel {
        do {
           return try transform()
        } catch LayoutTransformerError.missingData {
            return .empty
        } catch {
            throw error
        }
    }

    private func findImage(for key: String, in images: [String: CreativeImage]?) -> CreativeImage? {
        let imageKeys = key.split(separator: "|").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        for imageKey in imageKeys {
            if let image = images?[imageKey] {
                return image
            }
        }
        return nil
    }
}

private extension LayoutTransformer.Context {
    var mapToCreativeContext: CreativeContext? {
        switch self {
        case .outer:
                .outer
        case .inner(let inner):
            switch inner {
            case .positive(let offerModel):
                    .positiveResponse(offerModel)
            case .negative(let offerModel):
                    .negativeResponse(offerModel)
            case .generic(let offerModel):
                    .generic(offerModel)
            case .addToCart:
                nil
            }
        }
    }
}

private extension DataImageCarouselIndicators {
    var shouldShowProgress: Bool {
        guard let activeIndicatorMode else {
            return true
        }

        switch activeIndicatorMode {
        case .normal:
            return false
        case .timer:
            return true
        }
    }
}

private extension CarouselFadeInOutTransitionSettings {
    var doubleValue: Double {
        switch self.speed ?? .medium {
        case .fast:
            return 200
        case .medium:
            return 400
        case .slow:
            return 1000
        }
    }
}

private extension CarouselSlideInOutTransitionSettings {
    var doubleValue: Double {
        switch self.speed ?? .medium {
        case .fast:
            return 200
        case .medium:
            return 1000
        case .slow:
            return 2000
        }
    }
}

private extension CarouselTransition {
    var transtion: DataImageCarouselViewModel.Transition {
        switch self {
        case let .fadeInOut(settings):
            return .fadeInOut(settings.doubleValue)
        case let .slideInOut(settings):
            return .slideInOut(settings.doubleValue)
        }
    }
}

private extension ContainerStylingProperties {
    static func build(
        justifyContent: FlexJustification? = nil,
        alignItems: FlexAlignment? = nil,
        shadow: Shadow? = nil,
        overflow: Overflow? = nil,
        gap: Float? = nil,
        blur: Float? = nil
    ) -> ContainerStylingProperties {
        ContainerStylingProperties(
            justifyContent: justifyContent,
            alignItems: alignItems,
            shadow: shadow,
            overflow: overflow,
            gap: gap,
            blur: blur
        )
    }
}

private extension BasicStateStylingBlock<DataImageCarouselIndicatorStyles> {
    static func build(
        default: DataImageCarouselIndicatorStyles,
        pressed: DataImageCarouselIndicatorStyles? = nil,
        hovered: DataImageCarouselIndicatorStyles? = nil,
        focussed: DataImageCarouselIndicatorStyles? = nil,
        disabled: DataImageCarouselIndicatorStyles? = nil
    ) -> BasicStateStylingBlock<DataImageCarouselIndicatorStyles> {
        .init(
            default: `default`,
            pressed: pressed,
            hovered: hovered,
            focussed: focussed,
            disabled: disabled
        )
    }

    static var dafaultIndicatorStyle: Self = .build(
        default: .build(
            container: .build(overflow: .hidden),
            background: .init(backgroundColor: .init(light: "#66FFFFFF", dark: nil), backgroundImage: nil),
            border: .init(BorderStylingProperties(borderRadius: 4, borderColor: nil, borderWidth: nil, borderStyle: nil)),
            dimension: .build(maxWidth: 75, width: .fixed(8), height: .fixed(8))
        )
    )

    static var dafaultActiveIndicatorStyle: Self = .build(
        default: .build(
            background: .init(backgroundColor: .init(light: "#FFFFFF", dark: nil), backgroundImage: nil),
        )
    )

    static var dafaultProgressIndicatorStyle: Self = .build(
        default: .build(
            container: .build(justifyContent: .center, alignItems: .center, gap: 2),
            dimension: .build(width: .percentage(100)),
            spacing: .init(padding: nil, margin: nil, offset: "0 -10")
        )
    )
}

private extension DataImageCarouselIndicatorStyles {
    static func build(
        container: ContainerStylingProperties? = nil,
        background: BackgroundStylingProperties? = nil,
        border: BorderStylingProperties? = nil,
        dimension: DimensionStylingProperties? = nil,
        flexChild: FlexChildStylingProperties? = nil,
        spacing: SpacingStylingProperties? = nil
    ) -> DataImageCarouselIndicatorStyles {
        .init(
            container: container,
            background: background,
            border: border,
            dimension: dimension,
            flexChild: flexChild,
            spacing: spacing
        )
    }
}

private extension DimensionStylingProperties {
    static func build(
        minWidth: Float? = nil,
        maxWidth: Float? = nil,
        width: DimensionWidthValue? = nil,
        minHeight: Float? = nil,
        maxHeight: Float? = nil,
        height: DimensionHeightValue? = nil,
        rotateZ: Float? = nil
    ) -> DimensionStylingProperties {
        .init(
            minWidth: minWidth,
            maxWidth: maxWidth,
            width: width,
            minHeight: minHeight,
            maxHeight: maxHeight,
            height: height,
            rotateZ: rotateZ
        )
    }
}

private extension DataImageCarouselModel<WhenPredicate> {
    var progressIndicatorContainerStyles: [BasicStateStylingBlock<DataImageCarouselIndicatorStyles>] {
        styles?.elements?.progressIndicatorContainer ?? [.dafaultProgressIndicatorStyle]
    }

    var activeIndicatorStyles: [BasicStateStylingBlock<DataImageCarouselIndicatorStyles>] {
        styles?.elements?.activeIndicator ?? [.dafaultActiveIndicatorStyle]
    }

    var indicatorStyles: [BasicStateStylingBlock<DataImageCarouselIndicatorStyles>] {
        styles?.elements?.indicator ?? [.dafaultIndicatorStyle]
    }

    var seenIndicatorStyles: [BasicStateStylingBlock<DataImageCarouselIndicatorStyles>]? {
        styles?.elements?.seenIndicator
    }
}
