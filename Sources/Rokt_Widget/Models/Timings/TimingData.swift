import Foundation

/// Encapsulates timing metrics for a single selection (execute) call.
/// This class stores all timing data associated with a specific selectionId,
/// allowing concurrent execute calls to maintain independent timing states.
class TimingData {
    var experiencesRequestStart: Date?
    var experiencesRequestEnd: Date?
    var selectionStart: Date?
    var selectionEnd: Date?
    var pageInit: Date?
    var placementInteractive: Date?
    var jointSdkSelectPlacements: Date?
    var sessionId: String?
    var pageId: String?
    var pageInstanceGuid: String?
    var pluginId: String?
    var pluginName: String?

    init() {
        // Default initialization with nil values
    }
}
