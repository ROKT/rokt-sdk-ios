import Foundation

/// (Internal use only) Options for configuring placement behavior, including timing data from joint SDKs.
///
/// Use this class to pass timing information from an internal SDK to enable
/// accurate performance tracking across SDK boundaries.
@objcMembers public class PlacementOptions: NSObject {
    /// Timestamp (in milliseconds since epoch) when the joint SDK initiated placement selection.
    public let jointSdkSelectPlacements: Int64

    /// Dynamic performance markers for extensibility.
    public let dynamicPerformanceMarkers: [String: Int64]

    /// Creates a new PlacementOptions instance.
    ///
    /// - Parameters:
    ///   - jointSdkSelectPlacements: Timestamp in milliseconds since epoch when placement selection was initiated.
    ///   - dynamicPerformanceMarkers: Additional performance markers for future extensibility.
    public init(
        jointSdkSelectPlacements: Int64,
        dynamicPerformanceMarkers: [String: Int64] = [:]
    ) {
        self.jointSdkSelectPlacements = jointSdkSelectPlacements
        self.dynamicPerformanceMarkers = dynamicPerformanceMarkers
        super.init()
    }
}
