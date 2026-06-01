import Foundation

@available(iOS 15, *)
enum LayoutSchemaViewModel: Hashable {
    // top-level
    case overlay(OverlayViewModel)
    case bottomSheet(BottomSheetViewModel)

    case row(RowViewModel)
    case column(ColumnViewModel)
    case zStack(ZStackViewModel)
    case scrollableRow(RowViewModel)
    case scrollableColumn(ColumnViewModel)
    case when(WhenViewModel)
    case oneByOne(OneByOneViewModel)
    case carousel(CarouselViewModel)
    case groupDistribution(GroupedDistributionViewModel)

    case richText(RichTextViewModel)
    case basicText(BasicTextViewModel)
    case creativeResponse(CreativeResponseViewModel)
    case staticImage(StaticImageViewModel)
    case dataImage(DataImageViewModel)
    case progressIndicator(ProgressIndicatorViewModel)
    case closeButton(CloseButtonViewModel)
    case staticLink(StaticLinkViewModel)
    case progressControl(ProgressControlViewModel)
    case toggleButton(ToggleButtonViewModel)
    case dataImageCarousel(DataImageCarouselViewModel)
    case catalogStackedCollection(CatalogStackedCollectionViewModel)
    case catalogCombinedCollection(CatalogCombinedCollectionViewModel)
    case catalogDevicePayButton(CatalogDevicePayButtonViewModel)
    case catalogResponseButton(CatalogResponseButtonViewModel)
    case catalogDropdown(CatalogDropdownViewModel)
    case catalogImageGallery(CatalogImageGalleryViewModel)
    case empty
}

@available(iOS 15, *)
extension LayoutSchemaViewModel {

    static func == (lhs: LayoutSchemaViewModel, rhs: LayoutSchemaViewModel) -> Bool {
        switch (lhs, rhs) {
        case (.richText(let lhsModel), .richText(let rhsModel)):
            return lhsModel == rhsModel
        case (.basicText(let lhsModel), .basicText(let rhsModel)):
            return lhsModel == rhsModel
        case (.catalogResponseButton(let lhs), .catalogResponseButton(let rhs)):
            return lhs == rhs
        case (.catalogStackedCollection(let lhs), .catalogStackedCollection(let rhs)):
            return lhs == rhs
        case (.catalogCombinedCollection(let lhs), .catalogCombinedCollection(let rhs)):
            return lhs == rhs
        case (.catalogDevicePayButton(let lhs), .catalogDevicePayButton(let rhs)):
            return lhs == rhs
        case (.column(let lhsModel), .column(let rhsModel)):
            return lhsModel == rhsModel
        case (.row(let lhsModel), .row(let rhsModel)):
            return lhsModel == rhsModel
        case (.zStack(let lhsModel), .zStack(let rhsModel)):
            return lhsModel == rhsModel
        case (.scrollableRow(let lhsModel), .scrollableRow(let rhsModel)):
            return lhsModel == rhsModel
        case (.scrollableColumn(let lhsModel), .scrollableColumn(let rhsModel)):
            return lhsModel == rhsModel
        case (.creativeResponse(let lhsModel), .creativeResponse(let rhsModel)):
            return lhsModel == rhsModel
        case (.staticImage(let lhsModel), .staticImage(let rhsModel)):
            return lhsModel == rhsModel
        case (.dataImage(let lhsModel), .dataImage(let rhsModel)):
            return lhsModel == rhsModel
        case (.progressIndicator(let lhsModel), .progressIndicator(let rhsModel)):
            return lhsModel == rhsModel
        case (.oneByOne(let lhsModel), .oneByOne(let rhsModel)):
            return lhsModel == rhsModel
        case (.carousel(let lhsModel), .carousel(let rhsModel)):
            return lhsModel == rhsModel
        case (.groupDistribution(let lhsModel), .groupDistribution(let rhsModel)):
            return lhsModel == rhsModel
        case (.when(let lhsModel), .when(let rhsModel)):
            return lhsModel == rhsModel
        case (.closeButton(let lhsModel), .closeButton(let rhsModel)):
            return lhsModel == rhsModel
        case (.staticLink(let lhsModel), .staticLink(let rhsModel)):
            return lhsModel == rhsModel
        case (.progressControl(let lhsModel), .progressControl(let rhsModel)):
            return lhsModel == rhsModel
        case (.toggleButton(let lhsModel), .toggleButton(let rhsModel)):
            return lhsModel == rhsModel
        case (.dataImageCarousel(let lhsModel), .dataImageCarousel(let rhsModel)):
            return lhsModel == rhsModel
        case (.catalogDropdown(let lhs), .catalogDropdown(let rhs)):
            return lhs == rhs
        case (.catalogImageGallery(let lhs), .catalogImageGallery(let rhs)):
            return lhs == rhs
        case (.empty, .empty):
            return true
        default:
            return false
        }
    }
}
