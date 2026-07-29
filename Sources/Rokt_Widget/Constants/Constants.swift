import UIKit

// MARK: - API environment

var config = Configuration()
var baseURL: String {
  config.environment.baseURL
}

// MARK: - Library details

let libraryVersion = "5.3.0"

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

// MARK: - Diagnostic error codes

let fontDiagnosticCode = "[FONT]"

// MARK: - Network

let maxRetries = 3
