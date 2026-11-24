import Quick
import Nimble
import Foundation
@testable import Rokt_Widget

// MARK: Async waits

/// Budget for a single await of the execute → render pipeline.
///
/// Specs that step through that pipeline assertion by assertion — rather than waiting for a set of
/// events to land all at once — need one of these per step. The per-site budgets they used to carry
/// ranged from Nimble's 1s default up to 20s, while the pipeline itself measures 1.2–9.9s on runs
/// that pass, so the tighter ones reported a failure whenever CI happened to be slow.
///
/// `toEventually` returns as soon as its condition holds, so a generous budget costs nothing on a
/// healthy run. It only changes the outcome of a run that would otherwise have failed for want of a
/// second — at the price of a genuinely broken assertion taking longer to report. Examples chain two
/// of these, so keep it under half the `ui-test` job's `-default-test-execution-time-allowance`, or a
/// doubly-failing one is killed by the per-test timeout instead of naming the assertion.
let kPipelineWaitTimeout: NimbleTimeInterval = .seconds(30)

// MARK: Event expectations

/// Waits once for the required count of each listed (type, parent) pair and drains pending
/// event deliveries at a test-controlled boundary before failing on any overcounted listed pair.
func expectEventuallyRecorded(_ expected: [EventModel],
                              in events: @escaping @autoclosure () -> [EventModel],
                              timeout: NimbleTimeInterval = kPipelineWaitTimeout,
                              file: Nimble.FileString = #file,
                              line: UInt = #line) {
    let expectedCounts = countEvents(expected, matchPageInstance: false)
    expect(file: file, line: line) { () -> [String] in
        let missing = describeEventCountDifferences(
            expectedCounts,
            countEvents(events(), matchPageInstance: false),
            report: { expectedCount, actualCount in actualCount < expectedCount }
        )
        if !missing.isEmpty {
            return missing
        }
        EventQueue.flush()
        if !EventDeliveryFence.shared.isIdle {
            return ["waiting for event delivery to complete"]
        }
        return []
    }
    .toEventually(beEmpty(), timeout: timeout, description: "missing expected events or delivery still in flight")
    let excess = describeEventCountDifferences(
        expectedCounts,
        countEvents(events(), matchPageInstance: false),
        report: { expectedCount, actualCount in actualCount > expectedCount }
    )
    expect(file: file, line: line, excess).to(beEmpty(), description: "overcounted expected events")
}

/// Compares a snapshot by (type, parent, page instance), including unlisted events.
func expectRecordedExactly(_ expected: [EventModel], in events: [EventModel],
                           file: Nimble.FileString = #file, line: UInt = #line) {
    let differences = describeEventCountDifferences(countEvents(expected), countEvents(events),
                                                    includingUnlisted: true, report: { $0 != $1 })
    expect(file: file, line: line, differences).to(beEmpty(), description: "event counts to match exactly")
}

private func countEvents(_ events: [EventModel], matchPageInstance: Bool = true) -> [EventModel.CountKey: Int] {
    events.reduce(into: [:]) { counts, event in
        counts[event.countKey(matchPageInstance: matchPageInstance), default: 0] += 1
    }
}

private func describeEventCountDifferences(_ expected: [EventModel.CountKey: Int],
                                           _ actual: [EventModel.CountKey: Int],
                                           includingUnlisted: Bool = false,
                                           report: (Int, Int) -> Bool) -> [String] {
    let keys = includingUnlisted ? Set(expected.keys).union(actual.keys) : Set(expected.keys)
    return keys.compactMap { key -> String? in
        let wanted = expected[key, default: 0]
        let recorded = actual[key, default: 0]
        guard report(wanted, recorded) else { return nil }
        let page = key.pageInstanceGuid.map { ", page: \($0)" } ?? ""
        return "\(key.eventType)(parent: \(key.parentGuid)\(page)): expected \(wanted), recorded \(recorded)"
    }.sorted()
}

// MARK: Cache file utils

extension QuickSpec {
    func getJsonFileContents(_ fileName: String) -> String? {
        guard let url = Bundle(for: type(of: self)).url(forResource: fileName, withExtension: "json") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// The experience page the offers path renders for a v1 layout fixture, reshaped
    /// into the canonical offers response that the service forwards unchanged.
    func expectedOffersPage(forV1Fixture fileName: String) -> String? {
        guard let path = Bundle(for: type(of: self)).path(forResource: fileName, ofType: "json"),
              let v1Data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let offersData = makeOffersData(fromV1Experience: v1Data),
              let response = String(data: offersData, encoding: .utf8)
        else { return nil }
        return response
    }

    func prepareExperienceCacheTestFiles(_ testCacheDirectoryName: String) {
        ExperienceCacheManager.setCacheDirectoryName(testCacheDirectoryName)
    }

    /// Waits for the delete: it is an async barrier, while the next spec's first cache read is a direct
    /// synchronous file read, which could otherwise hit this spec's response just before it is deleted.
    func deleteExperienceCacheTestFiles() {
        let completion = DispatchSemaphore(value: 0)
        ExperienceCacheManager.clearCache(
            success: { completion.signal() },
            failure: { completion.signal() }
        )
        _ = completion.wait(timeout: .now() + 5)
    }
}
