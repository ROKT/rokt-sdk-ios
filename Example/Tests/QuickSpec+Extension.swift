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

/// Waits once for a whole set of expected events to arrive, instead of giving each event
/// its own polling budget.
///
/// The per-event form these specs used to spell out looked like this:
///
///     expect(events.contains(a)).toEventually(beTrue(), timeout: .seconds(10))
///     expect(events.contains(b)).toEventually(beTrue(), timeout: .seconds(10))
///     ...
///
/// Those budgets run in sequence rather than being shared, so the *first* assertion
/// silently absorbed the entire remaining latency of the placement pipeline — init, offers,
/// render, then the event POST the stub records. Every later assertion then found its event
/// already recorded and returned immediately. On a slow CI runner, where that pipeline is
/// occasionally slower than the 10s the first line allowed, the run failed on exactly one
/// line — always whichever event happened to be checked first — and passed on retry with no
/// code change. It read like a broken event when the only thing wrong was that one
/// assertion's share of the budget.
///
/// Waiting on the set as a whole removes that asymmetry: one budget for one pipeline, and
/// the failure lists every event still missing instead of only the first.
///
/// - Parameters:
///   - expected: Events that must all be recorded before the timeout elapses.
///   - events: Re-read on every poll, so pass the recording array itself.
///   - timeout: Budget for the whole set.
func expectEventuallyRecorded(_ expected: [EventModel],
                              in events: @escaping @autoclosure () -> [EventModel],
                              timeout: NimbleTimeInterval = .seconds(30),
                              file: Nimble.FileString = #file,
                              line: UInt = #line) {
    expect(file: file, line: line, describeMissingEvents(expected, in: events()))
        .toEventually(beEmpty(),
                      timeout: timeout,
                      description: "all expected events to be recorded")
}

/// Rendered as strings so a failure names the missing events by type and parent guid —
/// that pair is what identifies which stage of the placement never reported.
private func describeMissingEvents(_ expected: [EventModel], in events: [EventModel]) -> [String] {
    expected.filter { !events.contains($0) }
        .map { "\($0.eventType)(parent: \($0.parentGuid))" }
}

// MARK: Cache file utils

extension QuickSpec {
    func getJsonFileContents(_ fileName: String) -> String? {
        let path = Bundle(for: type(of: self)).path(forResource: fileName, ofType: "json")!
        return try? String(contentsOfFile: path)
    }

    /// The experience page the offers path renders for a v1 layout fixture: the
    /// fixture reshaped into the offers response, then adapted into the render
    /// contract. Mirrors what the offers service feeds the renderer, so cache
    /// assertions compare against the real output rather than the raw fixture.
    func expectedOffersPage(forV1Fixture fileName: String) -> String? {
        guard let path = Bundle(for: type(of: self)).path(forResource: fileName, ofType: "json"),
              let v1Data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let offersData = makeOffersData(fromV1Experience: v1Data),
              let response = try? JSONDecoder().decode(SelectResponse.self, from: offersData)
        else { return nil }
        return try? SelectExperienceAdapter.experienceJSONString(from: response)
    }

    func prepareExperienceCacheTestFiles(_ testCacheDirectoryName: String) {
        ExperienceCacheManager.setCacheDirectoryName(testCacheDirectoryName)
    }

    func deleteExperienceCacheTestFiles() {
        ExperienceCacheManager.clearCache()
    }
}
