import XCTest
@testable import MahiFinCore

struct FixedClock: Clock {
    let value: Date
    func now() -> Date { value }
}
actor FixtureHistoryRemote: HistoryRemote {
    private var value: MediaItem
    private var writes = 0
    private var loseResponse: Bool
    init(date: Date? = nil, loseResponse: Bool = false) {
        self.loseResponse = loseResponse
        value = MediaItem(id: "i", name: "Invented")
        value.UserData = UserData(PlaybackPositionTicks: 0, Played: false, IsFavorite: true, LastPlayedDate: date.map { ISO8601DateFormatter().string(from: $0) })
    }
    func item(user: String, id: String) async throws -> MediaItem { value }
    func savePosition(user: String, item: String, ticks: Int64, date: Date?, completed: Bool) async throws {
        writes += 1
        value.UserData?.PlaybackPositionTicks = completed ? 0 : ticks
        if completed { value.UserData?.Played = true }
        value.UserData?.LastPlayedDate = date.map { ISO8601DateFormatter().string(from: $0) }
        if loseResponse { loseResponse = false; throw ClientError.http(503) }
    }
    func snapshot() -> (MediaItem, Int) { (value, writes) }
}
final class HistorySyncTests: XCTestCase {
    func account(_ user: String) -> Account { .init(server: URL(string: "https://example.invalid")!, serverID: "s", userID: user, name: "Invented") }
    func testLostWriteResponseRetriedWithoutDuplicateMutation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let queue = try HistoryQueue(disk: DiskStore(root: root))
        let a = account("a"); let b = account("b")
        let clock = FixedClock(value: Date(timeIntervalSince1970: 1000))
        try await queue.record(account: a.id, item: "i", seconds: 720, completed: false, device: "fixture", clock: clock)
        try await queue.record(account: b.id, item: "i", seconds: 10, completed: false, device: "fixture", clock: clock)
        let remote = FixtureHistoryRemote(loseResponse: true)
        let first = await HistorySync.run(queue: queue, remote: remote, account: a, clock: clock)
        XCTAssertEqual(first.issue, "network")
        let second = await HistorySync.run(queue: queue, remote: remote, account: a, clock: clock)
        XCTAssertEqual(second.acknowledged, 1); XCTAssertNil(second.issue)
        let snapshot = await remote.snapshot()
        XCTAssertEqual(snapshot.1, 1)
        XCTAssertEqual(snapshot.0.UserData?.PlaybackPositionTicks, 7200000000)
        XCTAssertEqual(snapshot.0.UserData?.IsFavorite, true)
        let otherProfile = await queue.pending(account: b.id)
        XCTAssertEqual(otherProfile.count, 1)
    }
    func testCompletionAbsoluteStateAndNewerServerConflict() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let queue = try HistoryQueue(disk: DiskStore(root: root)); let a = account("a")
        let clock = FixedClock(value: Date(timeIntervalSince1970: 1000))
        try await queue.record(account: a.id, item: "i", seconds: 1500, completed: true, device: "fixture", clock: clock)
        let remote = FixtureHistoryRemote()
        let result = await HistorySync.run(queue: queue, remote: remote, account: a, clock: clock)
        XCTAssertEqual(result.acknowledged, 1)
        let completed = await remote.snapshot()
        XCTAssertEqual(completed.0.UserData?.Played, true); XCTAssertEqual(completed.0.UserData?.PlaybackPositionTicks, 0)
        try await queue.record(account: a.id, item: "i", seconds: 5, completed: false, device: "fixture", clock: clock)
        let newer = FixtureHistoryRemote(date: clock.value.addingTimeInterval(30))
        _ = await HistorySync.run(queue: queue, remote: newer, account: a, clock: clock)
        let newerSnapshot = await newer.snapshot()
        XCTAssertEqual(newerSnapshot.1, 0)
        try await queue.record(account: a.id, item: "i", seconds: 7, completed: false, device: "fixture", clock: clock)
        let skewed = FixtureHistoryRemote(date: clock.value.addingTimeInterval(600))
        let conflict = await HistorySync.run(queue: queue, remote: skewed, account: a, clock: clock)
        XCTAssertEqual(conflict.issue, "conflict")
        let pending = await queue.pending(account: a.id)
        XCTAssertEqual(pending.count, 1)
    }
}
