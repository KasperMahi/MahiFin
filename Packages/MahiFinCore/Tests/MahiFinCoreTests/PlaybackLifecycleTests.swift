import XCTest
@testable import MahiFinCore

final class PlaybackLifecycleTests: XCTestCase {
    func testAlternativePrerollAndEarlyStopPreserveSavedResume() {
        var gate = ResumeGate(position: 720)
        XCTAssertFalse(gate.observe(seconds: 0, duration: 2400))
        XCTAssertEqual(gate.stopPosition(seconds: 0), 720)
        XCTAssertFalse(gate.observe(seconds: .nan, duration: 2400))
        XCTAssertTrue(gate.observe(seconds: 719, duration: 2400))
        XCTAssertEqual(gate.stopPosition(seconds: 719), 719)
        // Once settled, an intentional seek back to zero is real activity.
        XCTAssertTrue(gate.observe(seconds: 0, duration: 2400))
        XCTAssertEqual(gate.stopPosition(seconds: 0), 0)
    }
    func testLateOldEngineCannotCompleteOrStopReplacement() {
        var ledger = PlaybackLedger()
        let first = ledger.begin(position: 720)
        XCTAssertTrue(ledger.checkpoint(730, generation: first))
        XCTAssertTrue(ledger.stop(generation: first)); XCTAssertFalse(ledger.stop(generation: first))
        let next = ledger.begin(position: 0)
        XCTAssertFalse(ledger.complete(generation: first)); XCTAssertFalse(ledger.checkpoint(900, generation: first))
        XCTAssertTrue(ledger.checkpoint(12, generation: next)); XCTAssertTrue(ledger.complete(generation: next))
        XCTAssertFalse(ledger.complete(generation: next)); XCTAssertTrue(ledger.stop(generation: next))
        XCTAssertEqual(ledger.stopCount, 2)
    }
    func testEarlyAbortNeverCompletesAndInvalidTimeIsRejected() {
        var ledger = PlaybackLedger(); let id = ledger.begin(position: 720)
        XCTAssertFalse(ledger.checkpoint(.nan, generation: id)); XCTAssertFalse(ledger.checkpoint(-1, generation: id))
        XCTAssertTrue(ledger.stop(generation: id)); XCTAssertFalse(ledger.completed)
        XCTAssertFalse(ledger.complete(generation: id))
    }
    func testSyncedOfflineResumeSurvivesAckRestartAndOtherProfile() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let disk = try DiskStore(root: root); let queue = try HistoryQueue(disk: disk)
        try await queue.record(account: "a", item: "i", seconds: 720, completed: false, device: "fixture")
        let pending = await queue.pending(account: "a")
        try await queue.acknowledge(pending[0])
        let restored = try HistoryQueue(disk: disk)
        let saved = await restored.latest(account: "a", item: "i")
        XCTAssertEqual(ResumePosition.local(item: .init(id: "i", name: "Invented"), pending: saved), 720)
        let other = await restored.latest(account: "b", item: "i")
        XCTAssertNil(other)
        let uploads = await restored.pending(account: "a")
        XCTAssertTrue(uploads.isEmpty)
    }
}
