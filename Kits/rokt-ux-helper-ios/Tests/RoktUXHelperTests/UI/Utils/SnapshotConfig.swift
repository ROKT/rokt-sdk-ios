import SnapshotTesting

/// Shared snapshot configuration so all snapshot tests use the same device and precision.
/// Update this single constant when changing the target device or tolerance.
let snapshotDevice: ViewImageConfig = .iPhone13Pro(.portrait)
