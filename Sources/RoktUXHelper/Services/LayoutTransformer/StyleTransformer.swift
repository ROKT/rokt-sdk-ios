import Foundation
import DcuiSchema

@available(iOS 13, *)
struct StyleTransformer {

    static func updatedStyles<T: Codable>(
        _ styles: [BasicStateStylingBlock<T>]?,
        transform: (T) -> BaseStyles
    ) throws -> [BasicStateStylingBlock<BaseStyles>] {
        try updatedStyles(styles).map {
            BasicStateStylingBlock(
                default: transform($0.default),
                pressed: $0.pressed.map(transform),
                hovered: $0.hovered.map(transform),
                focussed: $0.focussed.map(transform),
                disabled: $0.disabled.map(transform))
        }
    }

    static func updatedStyles<T: Codable>(
        _ styles: [BasicStateStylingBlock<T>]?
    ) throws -> [BasicStateStylingBlock<T>] {
        var updatedStyles: [BasicStateStylingBlock<T>] = []
        guard let styles, !styles.isEmpty else { return updatedStyles }

        var lastDefault: T?
        var lastPressed: T?
        var lastHovered: T?
        var lastFocussed: T?
        var lastDisabled: T?

        try styles.forEach { style in
            let defaultStyle = style.default

            if let lastDefaultValue = lastDefault {
                lastDefault = try updatedStyle(lastDefaultValue, newStyle: defaultStyle)
            } else {
                lastDefault = defaultStyle
            }
            if let lastPressedValue = lastPressed {
                lastPressed = try updatedStyle(lastPressedValue, newStyle: style.pressed)
            } else {
                lastPressed = style.pressed
            }
            if let lastHoveredValue = lastHovered {
                lastHovered = try updatedStyle(lastHoveredValue, newStyle: style.hovered)
            } else {
                lastHovered = style.hovered
            }
            if let lastFocussedValue = lastFocussed {
                lastFocussed = try updatedStyle(lastFocussedValue, newStyle: style.focussed)
            } else {
                lastFocussed = style.focussed
            }
            if let lastDisabledValue = lastDisabled {
                lastDisabled = try updatedStyle(lastDisabledValue, newStyle: style.disabled)
            } else {
                lastDisabled = style.disabled
            }

            updatedStyles.append(
                BasicStateStylingBlock(default: lastDefault ?? defaultStyle,
                                       pressed: try updatedStyle(lastDefault, newStyle: lastPressed),
                                       hovered: try updatedStyle(lastDefault, newStyle: lastHovered),
                                       focussed: try updatedStyle(lastDefault, newStyle: lastFocussed),
                                       disabled: try updatedStyle(lastDefault, newStyle: lastDisabled)))
        }

        return updatedStyles
    }

    static func updatedStyles<T: Codable>(
        _ styles: [FormStateStylingBlock<T>]?
    ) throws -> [FormStateStylingBlock<T>] {
        var updatedStyles: [FormStateStylingBlock<T>] = []
        guard let styles, !styles.isEmpty else { return updatedStyles }

        var lastDefault: T?
        var lastPressed: T?
        var lastHovered: T?
        var lastFocussed: T?
        var lastDisabled: T?
        var lastSelected: T?
        var lastErrored: T?

        try styles.forEach { style in
            let defaultStyle = style.default

            lastDefault = try lastDefault.map { try updatedStyle($0, newStyle: defaultStyle) } ?? defaultStyle
            lastPressed = try lastPressed.map { try updatedStyle($0, newStyle: style.pressed) } ?? style.pressed
            lastHovered = try lastHovered.map { try updatedStyle($0, newStyle: style.hovered) } ?? style.hovered
            lastFocussed = try lastFocussed.map { try updatedStyle($0, newStyle: style.focussed) } ?? style.focussed
            lastDisabled = try lastDisabled.map { try updatedStyle($0, newStyle: style.disabled) } ?? style.disabled
            lastSelected = try lastSelected.map { try updatedStyle($0, newStyle: style.selected) } ?? style.selected
            lastErrored = try lastErrored.map { try updatedStyle($0, newStyle: style.errored) } ?? style.errored

            updatedStyles.append(
                FormStateStylingBlock(default: lastDefault ?? defaultStyle,
                                      pressed: try updatedStyle(lastDefault, newStyle: lastPressed),
                                      hovered: try updatedStyle(lastDefault, newStyle: lastHovered),
                                      focussed: try updatedStyle(lastDefault, newStyle: lastFocussed),
                                      disabled: try updatedStyle(lastDefault, newStyle: lastDisabled),
                                      selected: try updatedStyle(lastDefault, newStyle: lastSelected),
                                      errored: try updatedStyle(lastDefault, newStyle: lastErrored)))
        }

        return updatedStyles
    }

    static func updatedStyles<T: Codable>(_ styles: [StatelessStylingBlock<T>]?) throws -> [StatelessStylingBlock<T>] {
        var updatedStyles: [StatelessStylingBlock<T>] = []
        guard let styles, !styles.isEmpty else { return updatedStyles }

        var lastDefault: T?

        try styles.forEach { style in
            let defaultStyle = style.default

            if let lastDefaultValue = lastDefault {
                lastDefault = try updatedStyle(lastDefaultValue, newStyle: defaultStyle)
            } else {
                lastDefault = defaultStyle
            }

            updatedStyles.append(
                StatelessStylingBlock(default: lastDefault ?? defaultStyle))
        }

        return updatedStyles
    }

    static func updatedIndicatorStyles<T: Codable>(
        _ styles: [BasicStateStylingBlock<T>]?,
        newStyles: [BasicStateStylingBlock<T>]?
    ) throws -> [BasicStateStylingBlock<T>] {
        var resultStyles: [BasicStateStylingBlock<T>] = []

        let prefilledStyle = try updatedStyles(styles)
        let prefilledNewStyle = try updatedStyles(newStyles)

        var styleIndex = 0
        var newStyleIndex = 0

        var lastDefaultIndicator: BasicStateStylingBlock<T>?
        var lastNewIndicator: BasicStateStylingBlock<T>?

        var lastDefault: T?
        var lastPressed: T?
        var lastHovered: T?
        var lastDisabled: T?

        while styleIndex < prefilledStyle.count || newStyleIndex < prefilledNewStyle.count {

            if prefilledStyle.count > styleIndex {
                lastDefaultIndicator = prefilledStyle[styleIndex]
            }

            if prefilledNewStyle.count > newStyleIndex {
                lastNewIndicator = prefilledNewStyle[newStyleIndex]
            }

            if let lastDefaultValue = lastDefault {
                lastDefault = try updatedStyle(lastDefaultValue, newStyle: lastDefaultIndicator?.default)
            } else {
                lastDefault = lastDefaultIndicator?.default
            }
            lastDefault = try updatedStyle(lastDefault, newStyle: lastNewIndicator?.default)

            if let lastPressedValue = lastPressed, let pressedStyle = lastDefaultIndicator?.pressed {
                lastPressed = try updatedStyle(lastPressedValue, newStyle: pressedStyle)
            } else {
                lastPressed = lastDefaultIndicator?.pressed
            }
            lastPressed = try updatedStyle(lastPressed, newStyle: lastNewIndicator?.pressed)

            if let lastHoveredValue = lastHovered, let hoveredStyle = lastDefaultIndicator?.hovered {
                lastHovered = try updatedStyle(lastHoveredValue, newStyle: hoveredStyle)
            } else {
                lastHovered = lastDefaultIndicator?.hovered
            }
            lastHovered = try updatedStyle(lastHovered, newStyle: lastNewIndicator?.hovered)

            if let lastDisabledValue = lastDisabled, let disabledStyle = lastDefaultIndicator?.disabled {
                lastDisabled = try updatedStyle(lastDisabledValue, newStyle: disabledStyle)
            } else {
                lastDisabled = lastDefaultIndicator?.disabled
            }
            lastDisabled = try updatedStyle(lastDisabled, newStyle: lastNewIndicator?.disabled)

            guard let lastDefault else { break }
            resultStyles.append(
                BasicStateStylingBlock(default: lastDefault,
                                       pressed: try updatedStyle(lastDefault, newStyle: lastPressed),
                                       hovered: try updatedStyle(lastDefault, newStyle: lastHovered),
                                       focussed: nil,
                                       disabled: try updatedStyle(lastDefault, newStyle: lastDisabled)))

            styleIndex += 1
            newStyleIndex += 1

        }

        return resultStyles
    }

    static func updatedStyle<T: Codable>(_ defaultStyle: T?,
                                         newStyle: T?) throws -> T? {
        if let defaultStyle = defaultStyle as? StylingPropertiesModel {
            let newStyle = newStyle as? StylingPropertiesModel
            return try getUpdatedStyle(defaultStyle, newStyle: newStyle) as? T
        } else if let defaultStyle = defaultStyle as? RowStyle {
            let newStyle = newStyle as? RowStyle
            return try getUpdatedStyle(defaultStyle, newStyle: newStyle) as? T
        } else if let defaultStyle = defaultStyle as? ScrollableRowStyle {
            let newStyle = newStyle as? ScrollableRowStyle
            return try getUpdatedStyle(defaultStyle, newStyle: newStyle) as? T
        } else if let defaultStyle = defaultStyle as? ColumnStyle {
            let newStyle = newStyle as? ColumnStyle
            return try getUpdatedStyle(defaultStyle, newStyle: newStyle) as? T
        } else if let defaultStyle = defaultStyle as? ScrollableColumnStyle {
            let newStyle = newStyle as? ScrollableColumnStyle
            return try getUpdatedStyle(defaultStyle, newStyle: newStyle) as? T
        } else if let defaultStyle = defaultStyle as? ZStackStyle {
            let newStyle = newStyle as? ZStackStyle
            return try getUpdatedStyle(defaultStyle, newStyle: newStyle) as? T
        } else if let defaultStyle = defaultStyle as? OneByOneDistributionStyles {
            let newStyle = newStyle as? OneByOneDistributionStyles
            return try getUpdatedStyle(defaultStyle, newStyle: newStyle) as? T
        } else if let defaultStyle = defaultStyle as? BasicTextStyle {
            let newStyle = newStyle as? BasicTextStyle
            return try getUpdatedStyle(defaultStyle, newStyle: newStyle) as? T
        } else if let defaultStyle = defaultStyle as? RichTextStyle {
            let newStyle = newStyle as? RichTextStyle
            return try getUpdatedStyle(defaultStyle, newStyle: newStyle) as? T
        } else if let defaultStyle = defaultStyle as? StaticImageStyles {
            let newStyle = newStyle as? StaticImageStyles
            return try getUpdatedStyle(defaultStyle, newStyle: newStyle) as? T
        } else if let defaultStyle = defaultStyle as? DataImageStyles {
            let newStyle = newStyle as? DataImageStyles
            return try getUpdatedStyle(defaultStyle, newStyle: newStyle) as? T
        } else if let defaultStyle = defaultStyle as? CloseButtonStyles {
            let newStyle = newStyle as? CloseButtonStyles
            return try getUpdatedStyle(defaultStyle, newStyle: newStyle) as? T
        } else if let defaultStyle = defaultStyle as? IndicatorStyles {
            let newStyle = newStyle as? IndicatorStyles
            return try getUpdatedStyle(defaultStyle, newStyle: newStyle) as? T
        } else if let defaultStyle = defaultStyle as? ProgressIndicatorStyles {
            let newStyle = newStyle as? ProgressIndicatorStyles
            return try getUpdatedStyle(defaultStyle, newStyle: newStyle) as? T
        } else if let defaultStyle = defaultStyle as? InLineTextStyle {
            let newStyle = newStyle as? InLineTextStyle
            return try getUpdatedStyle(defaultStyle, newStyle: newStyle) as? T
        } else if let defaultStyle = defaultStyle as? StaticLinkStyles {
            let newStyle = newStyle as? StaticLinkStyles
            return try getUpdatedStyle(defaultStyle, newStyle: newStyle) as? T
        } else if let defaultStyle = defaultStyle as? CreativeResponseStyles {
            let newStyle = newStyle as? CreativeResponseStyles
            return try getUpdatedStyle(defaultStyle, newStyle: newStyle) as? T
        } else if let defaultStyle = defaultStyle as? ProgressControlStyle {
            let newStyle = newStyle as? ProgressControlStyle
            return try getUpdatedStyle(defaultStyle, newStyle: newStyle) as? T
        } else if let defaultStyle = defaultStyle as? GroupedDistributionStyles {
            let newStyle = newStyle as? GroupedDistributionStyles
            return try getUpdatedStyle(defaultStyle, newStyle: newStyle) as? T
        } else if let defaultStyle = defaultStyle as? ToggleButtonStateTriggerStyle {
            let newStyle = newStyle as? ToggleButtonStateTriggerStyle
            return try getUpdatedStyle(defaultStyle, newStyle: newStyle) as? T
        } else if let defaultStyle = defaultStyle as? DataImageCarouselStyles {
            let newStyle = newStyle as? DataImageCarouselStyles
            return try getUpdatedStyle(defaultStyle, newStyle: newStyle) as? T
        } else if let defaultStyle = defaultStyle as? DataImageCarouselIndicatorStyles {
            let newStyle = newStyle as? DataImageCarouselIndicatorStyles
            return try getUpdatedStyle(defaultStyle, newStyle: newStyle) as? T
        } else if let defaultStyle = defaultStyle as? CatalogDevicePayButtonStyles {
            let newStyle = newStyle as? CatalogDevicePayButtonStyles
            return try getUpdatedStyle(defaultStyle, newStyle: newStyle) as? T
        } else if let defaultStyle = defaultStyle as? CatalogResponseButtonStyles {
            let newStyle = newStyle as? CatalogResponseButtonStyles
            return try getUpdatedStyle(defaultStyle, newStyle: newStyle) as? T
        }
        return nil
    }

    static func getUpdatedStyle(_ defaultStyle: StylingPropertiesModel?,
                                newStyle: StylingPropertiesModel?) throws -> StylingPropertiesModel {
        return StylingPropertiesModel(container: try updatedContainer(defaultStyle?.container,
                                                                      newStyle: newStyle?.container),
                                      background: try updatedBackground(defaultStyle?.background,
                                                                        newStyle: newStyle?.background),
                                      dimension: updatedDimension(defaultStyle?.dimension,
                                                                  newStyle: newStyle?.dimension),
                                      flexChild: updatedFlexChild(defaultStyle?.flexChild,
                                                                  newStyle: newStyle?.flexChild),
                                      spacing: updatedSpacing(defaultStyle?.spacing,
                                                              newStyle: newStyle?.spacing),
                                      border: try updatedBorder(defaultStyle?.border,
                                                                newStyle: newStyle?.border))
    }

    static func getUpdatedStyle(_ defaultStyle: RowStyle?,
                                newStyle: RowStyle?) throws -> RowStyle {
        return RowStyle(container: try updatedContainer(defaultStyle?.container,
                                                        newStyle: newStyle?.container),
                        background: try updatedBackground(defaultStyle?.background,
                                                          newStyle: newStyle?.background),
                        border: try updatedBorder(defaultStyle?.border,
                                                  newStyle: newStyle?.border),
                        dimension: updatedDimension(defaultStyle?.dimension,
                                                    newStyle: newStyle?.dimension),
                        flexChild: updatedFlexChild(defaultStyle?.flexChild,
                                                    newStyle: newStyle?.flexChild),
                        spacing: updatedSpacing(defaultStyle?.spacing,
                                                newStyle: newStyle?.spacing))
    }

    static func getUpdatedStyle(_ defaultStyle: ScrollableRowStyle?,
                                newStyle: ScrollableRowStyle?) throws -> ScrollableRowStyle {
        return ScrollableRowStyle(container: try updatedContainer(defaultStyle?.container,
                                                                  newStyle: newStyle?.container),
                                  background: try updatedBackground(defaultStyle?.background,
                                                                    newStyle: newStyle?.background),
                                  border: try updatedBorder(defaultStyle?.border,
                                                            newStyle: newStyle?.border),
                                  dimension: updatedDimension(defaultStyle?.dimension,
                                                              newStyle: newStyle?.dimension),
                                  flexChild: updatedFlexChild(defaultStyle?.flexChild,
                                                              newStyle: newStyle?.flexChild),
                                  spacing: updatedSpacing(defaultStyle?.spacing,
                                                          newStyle: newStyle?.spacing))
    }

    static func getUpdatedStyle(_ defaultStyle: ColumnStyle?,
                                newStyle: ColumnStyle?) throws -> ColumnStyle {
        return ColumnStyle(container: try updatedContainer(defaultStyle?.container,
                                                           newStyle: newStyle?.container),
                           background: try updatedBackground(defaultStyle?.background,
                                                             newStyle: newStyle?.background),
                           border: try updatedBorder(defaultStyle?.border,
                                                     newStyle: newStyle?.border),
                           dimension: updatedDimension(defaultStyle?.dimension,
                                                       newStyle: newStyle?.dimension),
                           flexChild: updatedFlexChild(defaultStyle?.flexChild,
                                                       newStyle: newStyle?.flexChild),
                           spacing: updatedSpacing(defaultStyle?.spacing,
                                                   newStyle: newStyle?.spacing))
    }

    static func getUpdatedStyle(_ defaultStyle: ScrollableColumnStyle?,
                                newStyle: ScrollableColumnStyle?) throws -> ScrollableColumnStyle {
        return ScrollableColumnStyle(container: try updatedContainer(defaultStyle?.container,
                                                                     newStyle: newStyle?.container),
                                     background: try updatedBackground(defaultStyle?.background,
                                                                       newStyle: newStyle?.background),
                                     border: try updatedBorder(defaultStyle?.border,
                                                               newStyle: newStyle?.border),
                                     dimension: updatedDimension(defaultStyle?.dimension,
                                                                 newStyle: newStyle?.dimension),
                                     flexChild: updatedFlexChild(defaultStyle?.flexChild,
                                                                 newStyle: newStyle?.flexChild),
                                     spacing: updatedSpacing(defaultStyle?.spacing,
                                                             newStyle: newStyle?.spacing))
    }

    static func getUpdatedStyle(_ defaultStyle: ZStackStyle?,
                                newStyle: ZStackStyle?) throws -> ZStackStyle {
        return ZStackStyle(container: try updatedZStackContainer(defaultStyle?.container,
                                                                 newStyle: newStyle?.container),
                           background: try updatedBackground(defaultStyle?.background,
                                                             newStyle: newStyle?.background),
                           border: try updatedBorder(defaultStyle?.border,
                                                     newStyle: newStyle?.border),
                           dimension: updatedDimension(defaultStyle?.dimension,
                                                       newStyle: newStyle?.dimension),
                           flexChild: updatedFlexChild(defaultStyle?.flexChild,
                                                       newStyle: newStyle?.flexChild),
                           spacing: updatedSpacing(defaultStyle?.spacing,
                                                   newStyle: newStyle?.spacing))
    }

    static func getUpdatedStyle(_ defaultStyle: OneByOneDistributionStyles?,
                                newStyle: OneByOneDistributionStyles?) throws -> OneByOneDistributionStyles {
        return OneByOneDistributionStyles(container: try updatedContainer(defaultStyle?.container,
                                                                          newStyle: newStyle?.container),
                                          background: try updatedBackground(defaultStyle?.background,
                                                                            newStyle: newStyle?.background),
                                          border: try updatedBorder(defaultStyle?.border,
                                                                    newStyle: newStyle?.border),
                                          dimension: updatedDimension(defaultStyle?.dimension,
                                                                      newStyle: newStyle?.dimension),
                                          flexChild: updatedFlexChild(defaultStyle?.flexChild,
                                                                      newStyle: newStyle?.flexChild),
                                          spacing: updatedSpacing(defaultStyle?.spacing,
                                                                  newStyle: newStyle?.spacing))
    }

    static func getUpdatedStyle(_ defaultStyle: CarouselDistributionStyles?,
                                newStyle: CarouselDistributionStyles?) throws -> CarouselDistributionStyles? {
        guard defaultStyle != nil || newStyle != nil else { return nil }
        return CarouselDistributionStyles(container: try updatedContainer(defaultStyle?.container,
                                                                          newStyle: newStyle?.container),
                                          background: try updatedBackground(defaultStyle?.background,
                                                                            newStyle: newStyle?.background),
                                          border: try updatedBorder(defaultStyle?.border,
                                                                    newStyle: newStyle?.border),
                                          dimension: updatedDimension(defaultStyle?.dimension,
                                                                      newStyle: newStyle?.dimension),
                                          flexChild: updatedFlexChild(defaultStyle?.flexChild,
                                                                      newStyle: newStyle?.flexChild),
                                          spacing: updatedSpacing(defaultStyle?.spacing,
                                                                  newStyle: newStyle?.spacing))
    }

    static func getUpdatedStyle(_ defaultStyle: BasicTextStyle?,
                                newStyle: BasicTextStyle?) throws -> BasicTextStyle {
        return BasicTextStyle(dimension: updatedDimension(defaultStyle?.dimension,
                                                          newStyle: newStyle?.dimension),
                              flexChild: updatedFlexChild(defaultStyle?.flexChild,
                                                          newStyle: newStyle?.flexChild),
                              spacing: updatedSpacing(defaultStyle?.spacing,
                                                      newStyle: newStyle?.spacing),
                              background: try updatedBackground(defaultStyle?.background,
                                                                newStyle: newStyle?.background),
                              text: try updatedText(defaultStyle?.text, newStyle: newStyle?.text))
    }

    static func getUpdatedStyle(_ defaultStyle: RichTextStyle?,
                                newStyle: RichTextStyle?) throws -> RichTextStyle {
        return RichTextStyle(dimension: updatedDimension(defaultStyle?.dimension,
                                                         newStyle: newStyle?.dimension),
                             flexChild: updatedFlexChild(defaultStyle?.flexChild,
                                                         newStyle: newStyle?.flexChild),
                             spacing: updatedSpacing(defaultStyle?.spacing,
                                                     newStyle: newStyle?.spacing),
                             background: try updatedBackground(defaultStyle?.background,
                                                               newStyle: newStyle?.background),
                             text: try updatedText(defaultStyle?.text, newStyle: newStyle?.text))
    }

    static func getUpdatedStyle(_ defaultStyle: StaticImageStyles?,
                                newStyle: StaticImageStyles?) throws -> StaticImageStyles {
        return StaticImageStyles(background: try updatedBackground(defaultStyle?.background,
                                                                   newStyle: newStyle?.background),
                                 border: try updatedBorder(defaultStyle?.border,
                                                           newStyle: newStyle?.border),
                                 dimension: updatedDimension(defaultStyle?.dimension,
                                                             newStyle: newStyle?.dimension),
                                 flexChild: updatedFlexChild(defaultStyle?.flexChild,
                                                             newStyle: newStyle?.flexChild),
                                 spacing: updatedSpacing(defaultStyle?.spacing,
                                                         newStyle: newStyle?.spacing))
    }

    static func getUpdatedStyle(_ defaultStyle: DataImageStyles?,
                                newStyle: DataImageStyles?) throws -> DataImageStyles {
        return DataImageStyles(background: try updatedBackground(defaultStyle?.background,
                                                                 newStyle: newStyle?.background),
                               border: try updatedBorder(defaultStyle?.border,
                                                         newStyle: newStyle?.border),
                               dimension: updatedDimension(defaultStyle?.dimension,
                                                           newStyle: newStyle?.dimension),
                               flexChild: updatedFlexChild(defaultStyle?.flexChild,
                                                           newStyle: newStyle?.flexChild),
                               spacing: updatedSpacing(defaultStyle?.spacing,
                                                       newStyle: newStyle?.spacing))
    }

    static func getUpdatedStyle(_ defaultStyle: CloseButtonStyles?,
                                newStyle: CloseButtonStyles?) throws -> CloseButtonStyles {
        return CloseButtonStyles(container: try updatedContainer(defaultStyle?.container,
                                                                 newStyle: newStyle?.container),
                                 background: try updatedBackground(defaultStyle?.background,
                                                                   newStyle: newStyle?.background),
                                 border: try updatedBorder(defaultStyle?.border,
                                                           newStyle: newStyle?.border),
                                 dimension: updatedDimension(defaultStyle?.dimension,
                                                             newStyle: newStyle?.dimension),
                                 flexChild: updatedFlexChild(defaultStyle?.flexChild,
                                                             newStyle: newStyle?.flexChild),
                                 spacing: updatedSpacing(defaultStyle?.spacing,
                                                         newStyle: newStyle?.spacing))
    }

    static func getUpdatedStyle(_ defaultStyle: IndicatorStyles?,
                                newStyle: IndicatorStyles?) throws -> IndicatorStyles {
        return IndicatorStyles(container: try updatedContainer(defaultStyle?.container,
                                                               newStyle: newStyle?.container),
                               background: try updatedBackground(defaultStyle?.background,
                                                                 newStyle: newStyle?.background),
                               border: try updatedBorder(defaultStyle?.border,
                                                         newStyle: newStyle?.border),
                               dimension: updatedDimension(defaultStyle?.dimension,
                                                           newStyle: newStyle?.dimension),
                               flexChild: updatedFlexChild(defaultStyle?.flexChild,
                                                           newStyle: newStyle?.flexChild),
                               spacing: updatedSpacing(defaultStyle?.spacing,
                                                       newStyle: newStyle?.spacing),
                               text: try updatedText(defaultStyle?.text, newStyle: newStyle?.text))
    }

    static func getUpdatedStyle(_ defaultStyle: ProgressIndicatorStyles?,
                                newStyle: ProgressIndicatorStyles?) throws -> ProgressIndicatorStyles {
        return ProgressIndicatorStyles(container: try updatedContainer(defaultStyle?.container,
                                                                       newStyle: newStyle?.container),
                                       background: try updatedBackground(defaultStyle?.background,
                                                                         newStyle: newStyle?.background),
                                       border: try updatedBorder(defaultStyle?.border,
                                                                 newStyle: newStyle?.border),
                                       dimension: updatedDimension(defaultStyle?.dimension,
                                                                   newStyle: newStyle?.dimension),
                                       flexChild: updatedFlexChild(defaultStyle?.flexChild,
                                                                   newStyle: newStyle?.flexChild),
                                       spacing: updatedSpacing(defaultStyle?.spacing,
                                                               newStyle: newStyle?.spacing))
    }

    static func getUpdatedStyle(_ defaultStyle: InLineTextStyle,
                                newStyle: InLineTextStyle?) throws -> InLineTextStyle {
        return InLineTextStyle(text: try updatedInLineText(defaultStyle.text, newStyle: newStyle?.text))
    }

    static func getUpdatedStyle(_ defaultStyle: StaticLinkStyles?,
                                newStyle: StaticLinkStyles?) throws -> StaticLinkStyles {
        return StaticLinkStyles(container: try updatedContainer(defaultStyle?.container,
                                                                newStyle: newStyle?.container),
                                background: try updatedBackground(defaultStyle?.background,
                                                                  newStyle: newStyle?.background),
                                border: try updatedBorder(defaultStyle?.border,
                                                          newStyle: newStyle?.border),
                                dimension: updatedDimension(defaultStyle?.dimension,
                                                            newStyle: newStyle?.dimension),
                                flexChild: updatedFlexChild(defaultStyle?.flexChild,
                                                            newStyle: newStyle?.flexChild),
                                spacing: updatedSpacing(defaultStyle?.spacing,
                                                        newStyle: newStyle?.spacing))
    }

    static func getUpdatedStyle(_ defaultStyle: CreativeResponseStyles?,
                                newStyle: CreativeResponseStyles?) throws -> CreativeResponseStyles {
        return CreativeResponseStyles(container: try updatedContainer(defaultStyle?.container,
                                                                      newStyle: newStyle?.container),
                                      background: try updatedBackground(defaultStyle?.background,
                                                                        newStyle: newStyle?.background),
                                      border: try updatedBorder(defaultStyle?.border,
                                                                newStyle: newStyle?.border),
                                      dimension: updatedDimension(defaultStyle?.dimension,
                                                                  newStyle: newStyle?.dimension),
                                      flexChild: updatedFlexChild(defaultStyle?.flexChild,
                                                                  newStyle: newStyle?.flexChild),
                                      spacing: updatedSpacing(defaultStyle?.spacing,
                                                              newStyle: newStyle?.spacing))
    }

    static func getUpdatedStyle(_ defaultStyle: ProgressControlStyle?,
                                newStyle: ProgressControlStyle?) throws -> ProgressControlStyle {
        return ProgressControlStyle(container: try updatedContainer(defaultStyle?.container,
                                                                    newStyle: newStyle?.container),
                                    background: try updatedBackground(defaultStyle?.background,
                                                                      newStyle: newStyle?.background),
                                    border: try updatedBorder(defaultStyle?.border,
                                                              newStyle: newStyle?.border),
                                    dimension: updatedDimension(defaultStyle?.dimension,
                                                                newStyle: newStyle?.dimension),
                                    flexChild: updatedFlexChild(defaultStyle?.flexChild,
                                                                newStyle: newStyle?.flexChild),
                                    spacing: updatedSpacing(defaultStyle?.spacing,
                                                            newStyle: newStyle?.spacing))
    }

    static func getUpdatedStyle(_ defaultStyle: GroupedDistributionStyles?,
                                newStyle: GroupedDistributionStyles?) throws -> GroupedDistributionStyles {
        return GroupedDistributionStyles(container: try updatedContainer(defaultStyle?.container,
                                                                         newStyle: newStyle?.container),
                                         background: try updatedBackground(defaultStyle?.background,
                                                                           newStyle: newStyle?.background),
                                         border: try updatedBorder(defaultStyle?.border,
                                                                   newStyle: newStyle?.border),
                                         dimension: updatedDimension(defaultStyle?.dimension,
                                                                     newStyle: newStyle?.dimension),
                                         flexChild: updatedFlexChild(defaultStyle?.flexChild,
                                                                     newStyle: newStyle?.flexChild),
                                         spacing: updatedSpacing(defaultStyle?.spacing,
                                                                 newStyle: newStyle?.spacing))
    }

    static func getUpdatedStyle(_ defaultStyle: ToggleButtonStateTriggerStyle?,
                                newStyle: ToggleButtonStateTriggerStyle?) throws -> ToggleButtonStateTriggerStyle {
        return ToggleButtonStateTriggerStyle(container: try updatedContainer(defaultStyle?.container,
                                                                             newStyle: newStyle?.container),
                                             background: try updatedBackground(defaultStyle?.background,
                                                                               newStyle: newStyle?.background),
                                             border: try updatedBorder(defaultStyle?.border,
                                                                       newStyle: newStyle?.border),
                                             dimension: updatedDimension(defaultStyle?.dimension,
                                                                         newStyle: newStyle?.dimension),
                                             flexChild: updatedFlexChild(defaultStyle?.flexChild,
                                                                         newStyle: newStyle?.flexChild),
                                             spacing: updatedSpacing(defaultStyle?.spacing,
                                                                     newStyle: newStyle?.spacing))
    }

    static func getUpdatedStyle(_ defaultStyle: DataImageCarouselStyles?,
                                newStyle: DataImageCarouselStyles?) throws -> DataImageCarouselStyles {
        return DataImageCarouselStyles(container: try updatedContainer(defaultStyle?.container,
                                                                       newStyle: newStyle?.container),
                                       background: try updatedBackground(defaultStyle?.background,
                                                                         newStyle: newStyle?.background),
                                       border: try updatedBorder(defaultStyle?.border,
                                                                 newStyle: newStyle?.border),
                                       dimension: updatedDimension(defaultStyle?.dimension,
                                                                   newStyle: newStyle?.dimension),
                                       flexChild: updatedFlexChild(defaultStyle?.flexChild,
                                                                   newStyle: newStyle?.flexChild),
                                       spacing: updatedSpacing(defaultStyle?.spacing,
                                                               newStyle: newStyle?.spacing))
    }

    static func getUpdatedStyle(_ defaultStyle: DataImageCarouselIndicatorStyles?,
                                newStyle: DataImageCarouselIndicatorStyles?) throws -> DataImageCarouselIndicatorStyles {
        return DataImageCarouselIndicatorStyles(container: try updatedContainer(defaultStyle?.container,
                                                                                newStyle: newStyle?.container),
                                                background: try updatedBackground(defaultStyle?.background,
                                                                                  newStyle: newStyle?.background),
                                                border: try updatedBorder(defaultStyle?.border,
                                                                          newStyle: newStyle?.border),
                                                dimension: updatedDimension(defaultStyle?.dimension,
                                                                            newStyle: newStyle?.dimension),
                                                flexChild: updatedFlexChild(defaultStyle?.flexChild,
                                                                            newStyle: newStyle?.flexChild),
                                                spacing: updatedSpacing(defaultStyle?.spacing,
                                                                        newStyle: newStyle?.spacing))
    }

    static func getUpdatedStyle(_ defaultStyle: CatalogDevicePayButtonStyles?,
                                newStyle: CatalogDevicePayButtonStyles?) throws -> CatalogDevicePayButtonStyles {
        return CatalogDevicePayButtonStyles(container: try updatedContainer(defaultStyle?.container,
                                                                            newStyle: newStyle?.container),
                                            background: try updatedBackground(defaultStyle?.background,
                                                                              newStyle: newStyle?.background),
                                            border: try updatedBorder(defaultStyle?.border,
                                                                      newStyle: newStyle?.border),
                                            dimension: updatedDimension(defaultStyle?.dimension,
                                                                        newStyle: newStyle?.dimension),
                                            flexChild: updatedFlexChild(defaultStyle?.flexChild,
                                                                        newStyle: newStyle?.flexChild),
                                            spacing: updatedSpacing(defaultStyle?.spacing,
                                                                    newStyle: newStyle?.spacing))
    }

    static func getUpdatedStyle(_ defaultStyle: CatalogResponseButtonStyles?,
                                newStyle: CatalogResponseButtonStyles?) throws -> CatalogResponseButtonStyles {
        return CatalogResponseButtonStyles(container: try updatedContainer(defaultStyle?.container,
                                                                           newStyle: newStyle?.container),
                                           background: try updatedBackground(defaultStyle?.background,
                                                                             newStyle: newStyle?.background),
                                           border: try updatedBorder(defaultStyle?.border,
                                                                     newStyle: newStyle?.border),
                                           dimension: updatedDimension(defaultStyle?.dimension,
                                                                       newStyle: newStyle?.dimension),
                                           flexChild: updatedFlexChild(defaultStyle?.flexChild,
                                                                       newStyle: newStyle?.flexChild),
                                           spacing: updatedSpacing(defaultStyle?.spacing,
                                                                   newStyle: newStyle?.spacing))
    }

    // MARK: Styling properties

    static func updatedContainer(_ defaultStyle: ContainerStylingProperties?,
                                 newStyle: ContainerStylingProperties?) throws -> ContainerStylingProperties? {
        guard defaultStyle != nil || newStyle != nil else { return nil }
        return ContainerStylingProperties(justifyContent: newStyle?.justifyContent ?? defaultStyle?.justifyContent,
                                          alignItems: newStyle?.alignItems ?? defaultStyle?.alignItems,
                                          shadow: try updatedShadow(defaultStyle?.shadow, newStyle: newStyle?.shadow),
                                          overflow: newStyle?.overflow ?? defaultStyle?.overflow,
                                          gap: newStyle?.gap ?? defaultStyle?.gap,
                                          blur: newStyle?.blur ?? defaultStyle?.blur)
    }

    static func updatedZStackContainer(_ defaultStyle: ZStackContainerStylingProperties?,
                                       newStyle: ZStackContainerStylingProperties?) throws -> ZStackContainerStylingProperties? {
        guard defaultStyle != nil || newStyle != nil else { return nil }
        return ZStackContainerStylingProperties(justifyContent: newStyle?.justifyContent ?? defaultStyle?.justifyContent,
                                                alignItems: newStyle?.alignItems ?? defaultStyle?.alignItems,
                                                shadow: try updatedShadow(defaultStyle?.shadow, newStyle: newStyle?.shadow),
                                                overflow: newStyle?.overflow ?? defaultStyle?.overflow,
                                                blur: newStyle?.blur ?? defaultStyle?.blur)
    }

    static func updatedBackground(_ defaultStyle: BackgroundStylingProperties?,
                                  newStyle: BackgroundStylingProperties?) throws -> BackgroundStylingProperties? {
        guard defaultStyle != nil || newStyle != nil else { return nil }
        return BackgroundStylingProperties(backgroundColor: try updatedColor(defaultStyle?.backgroundColor,
                                                                             newStyle: newStyle?.backgroundColor),
                                           backgroundImage: updatedBackgroundImage(defaultStyle?.backgroundImage,
                                                                                   newStyle: newStyle?.backgroundImage))
    }

    static func updatedDimension(_ defaultStyle: DimensionStylingProperties?,
                                 newStyle: DimensionStylingProperties?) -> DimensionStylingProperties? {
        guard defaultStyle != nil || newStyle != nil else { return nil }
        return DimensionStylingProperties(minWidth: newStyle?.minWidth ?? defaultStyle?.minWidth,
                                          maxWidth: newStyle?.maxWidth ?? defaultStyle?.maxWidth,
                                          width: newStyle?.width ?? defaultStyle?.width,
                                          minHeight: newStyle?.minHeight ?? defaultStyle?.minHeight,
                                          maxHeight: newStyle?.maxHeight ?? defaultStyle?.maxHeight,
                                          height: newStyle?.height ?? defaultStyle?.height,
                                          rotateZ: newStyle?.rotateZ ?? defaultStyle?.rotateZ)
    }

    static func updatedFlexChild(_ defaultStyle: FlexChildStylingProperties?,
                                 newStyle: FlexChildStylingProperties?) -> FlexChildStylingProperties? {
        guard defaultStyle != nil || newStyle != nil else { return nil }
        return FlexChildStylingProperties(weight: newStyle?.weight ?? defaultStyle?.weight,
                                          order: newStyle?.order ?? defaultStyle?.order,
                                          alignSelf: newStyle?.alignSelf ?? defaultStyle?.alignSelf)
    }

    static func updatedSpacing(_ defaultStyle: SpacingStylingProperties?,
                               newStyle: SpacingStylingProperties?) -> SpacingStylingProperties? {
        guard defaultStyle != nil || newStyle != nil else { return nil }
        return SpacingStylingProperties(padding: newStyle?.padding ?? defaultStyle?.padding,
                                        margin: newStyle?.margin ?? defaultStyle?.margin,
                                        offset: newStyle?.offset ?? defaultStyle?.offset)
    }

    static func updatedBorder(_ defaultStyle: BorderStylingProperties?,
                              newStyle: BorderStylingProperties?) throws -> BorderStylingProperties? {
        guard defaultStyle != nil || newStyle != nil else { return nil }
        return BorderStylingProperties(borderRadius: newStyle?.borderRadius ?? defaultStyle?.borderRadius,
                                       borderColor: try updatedColor(defaultStyle?.borderColor,
                                                                     newStyle: newStyle?.borderColor),
                                       borderWidth: newStyle?.borderWidth ?? defaultStyle?.borderWidth,
                                       borderStyle: newStyle?.borderStyle ?? defaultStyle?.borderStyle)
    }

    static func updatedText(_ defaultStyle: TextStylingProperties?,
                            newStyle: TextStylingProperties?) throws -> TextStylingProperties? {
        guard defaultStyle != nil || newStyle != nil else { return nil }
        return TextStylingProperties(textColor: try updatedColor(defaultStyle?.textColor, newStyle: newStyle?.textColor),
                                     fontSize: newStyle?.fontSize ?? defaultStyle?.fontSize,
                                     fontFamily: newStyle?.fontFamily ?? defaultStyle?.fontFamily,
                                     fontWeight: newStyle?.fontWeight ?? defaultStyle?.fontWeight,
                                     lineHeight: newStyle?.lineHeight ?? defaultStyle?.lineHeight,
                                     horizontalTextAlign: newStyle?.horizontalTextAlign ?? defaultStyle?.horizontalTextAlign,
                                     baselineTextAlign: newStyle?.baselineTextAlign ?? defaultStyle?.baselineTextAlign,
                                     fontStyle: newStyle?.fontStyle ?? defaultStyle?.fontStyle,
                                     textTransform: newStyle?.textTransform ?? defaultStyle?.textTransform,
                                     letterSpacing: newStyle?.letterSpacing ?? defaultStyle?.letterSpacing,
                                     textDecoration: newStyle?.textDecoration ?? defaultStyle?.textDecoration,
                                     lineLimit: newStyle?.lineLimit ?? defaultStyle?.lineLimit)
    }

    static func updatedInLineText(_ defaultStyle: InlineTextStylingProperties,
                                  newStyle: InlineTextStylingProperties?) throws -> InlineTextStylingProperties {
        return InlineTextStylingProperties(textColor: try updatedColor(defaultStyle.textColor, newStyle: newStyle?.textColor),
                                           fontSize: newStyle?.fontSize ?? defaultStyle.fontSize,
                                           fontFamily: newStyle?.fontFamily ?? defaultStyle.fontFamily,
                                           fontWeight: newStyle?.fontWeight ?? defaultStyle.fontWeight,
                                           baselineTextAlign: newStyle?.baselineTextAlign ?? defaultStyle.baselineTextAlign,
                                           fontStyle: newStyle?.fontStyle ?? defaultStyle.fontStyle,
                                           textTransform: newStyle?.textTransform ?? defaultStyle.textTransform,
                                           letterSpacing: newStyle?.letterSpacing ?? defaultStyle.letterSpacing,
                                           textDecoration: newStyle?.textDecoration ?? defaultStyle.textDecoration)
    }

    // MARK: Styles

    static func updatedShadow(_ defaultStyle: Shadow?,
                              newStyle: Shadow?) throws -> Shadow? {
        guard let defaultStyle else { return nil }
        return Shadow(offsetX: newStyle?.offsetX ?? defaultStyle.offsetX,
                      offsetY: newStyle?.offsetY ?? defaultStyle.offsetY,
                      blurRadius: newStyle?.blurRadius ?? defaultStyle.blurRadius,
                      spreadRadius: newStyle?.spreadRadius ?? defaultStyle.spreadRadius,
                      color: try updatedShadowColor(defaultStyle.color, newStyle: newStyle?.color))
    }

    static func updatedShadowColor(_ defaultStyle: ThemeColor,
                                   newStyle: ThemeColor?) throws -> ThemeColor {
        let lightColor = newStyle?.light ?? defaultStyle.light
        let darkColor = newStyle?.dark ?? defaultStyle.dark
        if !LayoutValidator.isValidColor(lightColor) {
            throw (LayoutTransformerError.InvalidColor(color: lightColor))
        }
        if let darkColor,
           !LayoutValidator.isValidColor(darkColor) {
            throw (LayoutTransformerError.InvalidColor(color: darkColor))
        }
        return ThemeColor(light: newStyle?.light ?? defaultStyle.light,
                          dark: newStyle?.dark ?? defaultStyle.dark)
    }

    static func updatedColor(_ defaultStyle: ThemeColor?,
                             newStyle: ThemeColor?) throws -> ThemeColor? {
        guard defaultStyle != nil || newStyle != nil ||
                newStyle?.light != nil || defaultStyle?.light != nil else {return nil}
        let lightColor = (newStyle?.light ?? defaultStyle?.light) ?? ""
        let darkColor = newStyle?.dark ?? defaultStyle?.dark
        guard LayoutValidator.isValidColor(lightColor) else {
            throw (LayoutTransformerError.InvalidColor(color: lightColor))
        }
        if let darkColor,
           !LayoutValidator.isValidColor(darkColor) {
            throw (LayoutTransformerError.InvalidColor(color: darkColor))
        }
        return ThemeColor(light: (newStyle?.light ?? defaultStyle?.light) ?? "",
                          dark: newStyle?.dark ?? defaultStyle?.dark)
    }

    static func updatedBackgroundImage(_ defaultStyle: BackgroundImage?,
                                       newStyle: BackgroundImage?) -> BackgroundImage? {
        guard defaultStyle != nil || newStyle != nil,
              let updatedUrl = updatedUrl(defaultStyle?.url, newStyle: newStyle?.url) else {return nil}
        return BackgroundImage(url: updatedUrl,
                               position: newStyle?.position ?? defaultStyle?.position,
                               scale: newStyle?.scale ?? defaultStyle?.scale)
    }

    static func updatedUrl(_ defaultStyle: ThemeUrl?,
                           newStyle: ThemeUrl?) -> ThemeUrl? {
        guard defaultStyle != nil || newStyle != nil else { return nil }
        return ThemeUrl(light: (newStyle?.light ?? defaultStyle?.light) ?? "",
                        dark: newStyle?.dark ?? defaultStyle?.dark)
    }

    // MARK: Convertors

    static func convertToRowStyles(_ style: ScrollableRowStyle?) -> RowStyle? {
        guard let style else { return nil }
        return RowStyle(container: style.container,
                        background: style.background,
                        border: style.border,
                        dimension: style.dimension,
                        flexChild: style.flexChild,
                        spacing: style.spacing)
    }

    static func convertToColumnStyles(_ style: ScrollableColumnStyle?) -> ColumnStyle? {
        guard let style else { return nil }
        return ColumnStyle(container: style.container,
                           background: style.background,
                           border: style.border,
                           dimension: style.dimension,
                           flexChild: style.flexChild,
                           spacing: style.spacing)
    }
}
