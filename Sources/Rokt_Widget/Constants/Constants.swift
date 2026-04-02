import UIKit

// MARK: - API environment

var config = Configuration()
var baseURL: String {
  config.environment.baseURL
}

// MARK: - Library details

let libraryVersion = "4.16.3"

// MARK: - Timings API keys

let timingsEventTimeKey = "eventTime"
let timingsPluginIdKey = "pluginId"
let timingsPluginNameKey = "pluginName"

// MARK: - API keys

let attributesKey = "attributes"
let sessionIdKey = "sessionId"
let pageInstanceGuidKey = "pageInstanceGuid"
let eventTypeKey = "eventType"
let parentGuidKey = "parentGuid"
let metadataKey = "metadata"
let finishedDownloadingFonts = "finishedDownloadingFonts"

// MARK: - String keys

let parsingLayoutError = "Error parsing layout, "

// MARK: - Diagnostic error codes

let fontDiagnosticCode = "[FONT]"
let validationDiagnosticCode = "[VALIDATION]"

// MARK: - Network

let maxRetries = 3

// MARK: - Header to switch between Placement and DCUI

let experienceTypeHeader = "rokt-experience-type"
let placementsValue = "placements"
let layoutsValue = "layouts"
