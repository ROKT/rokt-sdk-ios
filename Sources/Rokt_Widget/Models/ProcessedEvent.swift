import Foundation

// In-memory dedup key for an event. `eventType` is the wire event-type string
// (`impression`, `signal_response`, …) for platform events, or the legacy enum
// raw value for the SDK's own `EventRequest` path — either way a stable string.
struct ProcessedEvent: Hashable, Equatable {
    let sessionId: String
    let parentGuid: String
    let eventType: String
    let pageInstanceGuid: String
    let attributes: [String: String]
}

extension ProcessedEvent {
    private var attributesAsString: String {
        attributes
            .sorted(by: { $0.key < $1.key })
            .map { "\($0):\($1)" }
            .joined(separator: "")
    }

    public func getHashString() -> String {
        return [sessionId, parentGuid, eventType, pageInstanceGuid, attributesAsString]
            .joined(separator: "")
            .sha256()
    }
}
