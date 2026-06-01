// MARK: - Timings API keys

let BE_TIMINGS_EVENT_TIME_KEY = "eventTime"
let BE_TIMINGS_PLUGIN_ID_KEY = "pluginId"
let BE_TIMINGS_PLUGIN_NAME_KEY = "pluginName"
let BE_HEADER_PAGE_INSTANCE_GUID_KEY = "rokt-page-instance-guid"

// MARK: - API keys

let BE_EVENT_DATA_KEY = "eventData"
let BE_VIEW_NAME_KEY = "pageIdentifier"
let BE_SESSION_ID_KEY = "sessionId"
let BE_PAGE_INSTANCE_GUID_KEY = "pageInstanceGuid"
let BE_EVENT_TYPE_KEY = "eventType"
let BE_INSTANCE_GUID = "instanceGuid"
let BE_PARENT_GUID_KEY = "parentGuid"
let BE_CLIENT_TIME_STAMP = "clientTimeStamp"
let BE_METADATA_KEY = "metadata"
let BE_NAME = "name"
let BE_VALUE = "value"
let BE_CAPTURE_METHOD = "captureMethod"
let BE_PAGE_SIGNAL_LOAD = "pageSignalLoadStart"
let BE_PAGE_SIGNAL_COMPLETE = "pageSignalLoadComplete"
let BE_PAGE_RENDER_ENGINE = "pageRenderEngine"
let BE_RENDER_ENGINE_LAYOUTS = "Layouts"
let BE_JWT_TOKEN = "token"
let BE_OBJECT_DATA_KEY = "objectData"
let kEventTimeStamp = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
let kUTCTimeStamp = "UTC"
let kBaseLocale = "en"
let kClientProvided = "ClientProvided"
let kInitiator = "initiator"
let kCloseButton = "CLOSE_BUTTON"
let kNoMoreOfferToShow = "NO_MORE_OFFERS_TO_SHOW"
let kCollapsed = "COLLAPSED"
let kEndMessage = "END_MESSAGE"
let kInstantPurchaseDismiss = "INSTANT_PURCHASE_DISMISSED"
let kDismissed = "DISMISSED"
let kPartnerTriggered = "PARTNER_TRIGGERED"

// MARK: - String keys

let kEmbeddedLayoutDoesntExistMessage = "Error embedded layout doesn't exist "
let kUIFontErrorMessage = "Font family not found: "
let kStaticPageError = "Error on static page"
let kInvalidHTMLFormatError = "Error parsing html: "
let kLocationDoesNotExist = " location does not exist"
let kColorInvalid = "The color is invalid: "
let kLayoutInvalid = "The layout is invalid"

// MARK: - Diagnostic error codes

let kAPIExecuteErrorCode = "[EXECUTE]"
let kValidationErrorCode = "[VALIDATION]"
let kWebViewErrorCode = "[WEBVIEW]"
let kUrlErrorCode = "[URL]"
let kViewErrorCode = "[VIEW]"
let kForwardPaymentProcessingErrorCode = "[FORWARD_PAYMENT_PROCESSING]"
let kDevicePayProcessingErrorCode = "[DEVICE_PAY_PROCESSING]"
let kEmptyResponse = "Empty response from API"
let kErrorCode = "code"
let kErrorStackTrace = "stackTrace"
let kErrorSeverity = "severity"

// MARK: Queue

let kSharedDataItemsQueueLabel = "com.rokt.shareddata.items.queue"

// MARK: - Accessibility

let kPageAnnouncement = "Page %d of %d"
let kOneByOneAnnouncement = "Offer %d of %d"
let kProgressIndicatorAnnouncement = "%d of %d"

/// Generic `creative.images` alt strings from the backend that are not meaningful for VoiceOver.
let kNonDescriptiveCreativeImageAltTexts: Set<String> = [
    "image",
    "img",
    "photo",
    "picture",
    "1.91:1 image",
    "transparent 1.91:1 image",
    "logo image",
    "1.91:1 logo image",
    "transparent 1.91:1 logo image",
    "transparent logo image",
    "transparent image"
]

// MARK: Cart Item Instant purchase constants

let kCartItemId = "cartItemId"
let kCatalogItemId = "catalogItemId"
let kCurrency = "currency"
let kDescription = "description"
let kLinkedProductId = "linkedProductId"
let kTotalPrice = "totalPrice"
let kQuantity = "quantity"
let kUnitPrice = "unitPrice"
let kAction = "action"
let kContext = "context"
