import UIKit

// MARK: - API environment

var config = Configuration()
var kBaseURL: String {
  config.environment.baseURL
}

// MARK: - Library details

let kLibraryVersion = "4.16.1"

// MARK: - Init resource

let kInitResource = "init"
let kInitResourceVersion = "v1"
var kInitResourceUrl: String {
  "\(kBaseURL)/\(kInitResourceVersion)/\(kInitResource)"
}

// MARK: - Experiences resouce

let kExperiencesResource = "experiences"
let kExperiencesResourceVersion = "v1"
var kExperiencesResourceURL: String { "\(kBaseURL)/\(kExperiencesResourceVersion)/\(kExperiencesResource)" }

// MARK: - Event resource

let kEventResource = "events"
let kEventResourceVersion = "v2"
var kEventResourceUrl: String {
  "\(kBaseURL)/\(kEventResourceVersion)/\(kEventResource)"
}
let kEventAPIFailureMsg = "response: %@ ,statusCode: %@ ,error: %@"

// MARK: - Diagnostics resource

let kDiagnosticsResource = "diagnostics"
let kDiagnosticsResourceVersion = "v1"
var kDiagnosticsResourceUrl: String {
  "\(kBaseURL)/\(kDiagnosticsResourceVersion)/\(kDiagnosticsResource)"
}

// MARK: - Timings resource

let kTimingsResource = "timings"
let kTimingsResourceVersion = "v1"
var kTimingsResourceUrl: String {
  "\(kBaseURL)/\(kTimingsResourceVersion)/\(kTimingsResource)"
}
let kTimingsAPIFailureMsg = "response: %@, statusCode: %@, error: %@"

// MARK: - Timings API keys

let BE_TIMINGS_EVENT_TIME_KEY = "eventTime"
let BE_TIMINGS_TIMING_METRICS_KEY = "timingMetrics"
let BE_TIMINGS_PLUGIN_ID_KEY = "pluginId"
let BE_TIMINGS_PLUGIN_NAME_KEY = "pluginName"

// MARK: - Common Headers

let BE_HEADER_SESSION_ID_KEY = "rokt-session-id"
let BE_TAG_ID_KEY = "rokt-tag-id"
let BE_TRACKING_CONSENT = "rokt-apple-tracking-consent"
let BE_SDK_FRAMEWORK_TYPE = "rokt-sdk-framework-type"
let BE_HEADER_INTEGRATION_TYPE_KEY = "rokt-integration-type"
let BE_HEADER_PAGE_INSTANCE_GUID_KEY = "rokt-page-instance-guid"
let BE_HEADER_PAGE_ID_KEY = "rokt-page-id"

// MARK: - API keys

let BE_ATTRIBUTES_KEY = "attributes"
let BE_EVENT_DATA_KEY = "eventData"
let BE_ATTRIBUTES_PAGE_INIT_KEY = "pageinit"
let BE_VIEW_NAME_KEY = "pageIdentifier"
let BE_SESSION_ID_KEY = "sessionId"
let BE_PAGE_INSTANCE_GUID_KEY = "pageInstanceGuid"
let BE_FONT_NAME_KEY = "fontName"
let BE_FONT_URL_KEY = "fontUrl"
let BE_FONT_POSTSCRIPT_NAME_KEY = "fontPostScriptName"
let BE_CLIENT_TIMEOUT_KEY = "clientTimeoutMilliseconds"
let BE_DEFAULT_LAUNCH_DELAY_KEY = "defaultLaunchDelayMilliseconds"
let BE_CLIENT_SESSION_TIMEOUT_KEY = "clientSessionTimeoutMilliseconds"
let BE_LOG_FONT_KEY = "shouldLogFontHappyPath"
let BE_USE_FONT_REGISTERY_URL_KEY = "shouldUseFontRegisterWithUrl"
let BE_ROKT_FLAG_KEY = "roktTrackingStatus"
let BE_FEATURE_FLAG_KEY = "featureFlags"
let BE_FONTS_KEY = "fonts"
let BE_EVENT_TYPE_KEY = "eventType"
let BE_PARENT_GUID_KEY = "parentGuid"
let BE_CLIENT_TIME_STAMP = "clientTimeStamp"
let BE_METADATA_KEY = "metadata"
let BE_NAME = "name"
let BE_VALUE = "value"
let BE_CAPTURE_METHOD = "captureMethod"
let BE_PAGE_SIGNAL_LOAD = "pageSignalLoadStart"
let BE_ERROR_CODE_KEY = "code"
let BE_ERROR_STACK_TRACE_KEY = "stackTrace"
let BE_ERROR_SEVERITY_KEY = "severity"
let BE_ERROR_ADDITIONAL_KEY = "additionalInformation"
let BE_ERROR_SESSIONID_KEY = "sessionId"
let BE_ERROR_CAMPAIGNID_KEY = "campaignId"
let kDownloadingFonts = "downloadingFonts"
let kFinishedDownloadingFonts = "finishedDownloadingFonts"
let kEventTimeStamp = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
let kUTCTimeStamp = "UTC"
let kBaseLocale = "en"
let kClientProvided = "ClientProvided"

// MARK: - String keys

let kNetworkErrorKey = "network_error"
let kNetworkErrorComment = "Network connection error"
let kUnauthorizedKey = "unauthorized"
let kUnauthorizedComment = "Unauthorized"
let kApiErrorKey = "api_error"
let kApiErrorC = "API error: No response"
let kApiResponseKey = "api_response"
let kApiResponseComment = "API response"
let kTrackError = "tracking consent not authorised"
let kAPIFontErrorMessage = "Error downloading font: "
let kNoResponse = "No response from API"
let kEmptyResponse = "Empty response from API"
let kInitFailedError = "INIT_FAILED"
let kFontFailedError = "FONT_FAILED"
let kDefaultRoktInitEvent = "DEFAULT_ROKT_INIT_EVENT"
let kParsingLayoutError = "Error parsing layout, "

// MARK: - Diagnostic error codes

let kAPIInitErrorCode = "[INIT]"
let kAPIExecuteErrorCode = "[EXECUTE]"
let kAPIEventErrorCode = "[EVENT]"
let kAPIFontErrorCode = "[FONT]"
let kAPIFullFontLogCode = "[FULLFONTLOGS]"
let kValidationErrorCode = "[VALIDATION]"
let kUrlErrorCode = "[URL]"

let kTrackErrorCode = "[TRACKINGCONSENT]"

let kNotInitializedCode = "[NOT_INITIALIZED]"
let kAPITimingsErrorCode = "[TIMINGS]"
let kCacheHitCode = "[CACHE_HIT]"
let kErrorCode = "code"
let kErrorStackTrace = "stackTrace"

// MARK: - Network

let kBundleShort = "CFBundleShortVersionString"
let kArrayResponseKey = "array"
let kMaxRetries = 3

// MARK: - CPRA/Privacy flags in attributes

// top-level key
let BE_PRIVACY_CONTROL_KEY = "privacyControl"

// payload keys
let kNoFunctional = "noFunctional"
let kNoTargeting = "noTargeting"
let kDoNotShareOrSell = "doNotShareOrSell"
let kGpcEnabled = "gpcEnabled"

// MARK: - Header to switch between Placement and DCUI

let kExperienceType = "rokt-experience-type"
let kPlacementsValue = "placements"
let kLayoutsValue = "layouts"

let kLayoutsSchemaVersionHeader = "rokt-layout-schema-version"
// to be manually updated whenever we pull in a new schema version
let kLayoutsSchemaVersion = "2.3"

// MARK: - Font error messages

let kRegisterGraphicsFontErrorMsg = "font: %@, error: registerGraphicsFont on device %@"
let kRegisterURLFontErrorMsg = "font: %@, error: registerURLFont on device %@"

// MARK: - Full font log keys

let kFullFontLogCode1 = "[FFL001]"
let kFullFontLogCode2 = "[FFL002]"
let kFullFontLogCode3 = "[FFL003]"
let kFullFontLogCode4 = "[FFL004]"
let kFullFontLogCode5 = "[FFL005]"
let kFullFontLogCode6 = "[FFL006]"
let kFullFontLogCode7 = "[FFL007]"
let kFullFontLogCode8 = "[FFL008]"
let kFullFontLogCode9 = "[FFL009]"
let kLogFontPreloadedType = "pre-loaded"
let kLogFontDownloadedType = "downloaded"

// MARK: - Static feature flag

let kEventsLoggingEnabled = false

// MARK: - Timings constants

let kTimingsSDKType = "msdk"

// MARK: - Cache Diagnostics

let kCacheDurationKey = "cacheDuration"
let kCacheAttributesKey = "cacheAttributeKeys"
let kCacheHitMessage = "Cache hit for view - %@"
