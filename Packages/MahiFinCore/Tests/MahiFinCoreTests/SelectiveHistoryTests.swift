import XCTest
@testable import MahiFinCore

actor SelectiveHistoryRemote: HistoryRemote {
    var writes: [String] = []
    func item(user: String, id: String) async throws -> MediaItem {
        var item = MediaItem(id: id, name: "Invented")
        if id == "conflict" { item.UserData = .init(PlaybackPositionTicks: 1, Played: false, IsFavorite: true, LastPlayedDate: "1970-01-01T00:26:40Z") }
        return item
    }
    func savePosition(user: String, item: String, ticks: Int64, date: Date?, completed: Bool) async throws { writes.append(item) }
    func snapshot() -> [String] { writes }
}
final class SelectiveHistoryTests: XCTestCase {
    func testClockConflictDoesNotBlockUnrelatedItem() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let queue = try HistoryQueue(disk: DiskStore(root: root))
        let account = Account(server: URL(string: "https://example.invalid")!, serverID: "s", userID: "u", name: "Invented")
        let clock = FixedClock(value: Date(timeIntervalSince1970: 1000))
        for item in ["conflict", "unrelated"] { try await queue.record(account: account.id, item: item, seconds: 720, completed: false, device: "fixture", clock: clock) }
        let remote = SelectiveHistoryRemote()
        let result = await HistorySync.run(queue: queue, remote: remote, account: account, clock: clock)
        let writes = await remote.snapshot(); let pending = await queue.pending(account: account.id)
        XCTAssertEqual(writes, ["unrelated"]); XCTAssertEqual(result.issue, "conflict")
        XCTAssertEqual(pending.map(\.item), ["conflict"])
    }
    func testServerWinsUpdatesOfflineCacheWithoutRemovingNewerLocalEvent() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let queue = try HistoryQueue(disk: DiskStore(root: root))
        try await queue.record(account: "a", item: "i", seconds: 720, completed: false, device: "fixture")
        let old = await queue.pending(account: "a")[0]
        var server = MediaItem(id: "i", name: "Invented")
        server.UserData = .init(PlaybackPositionTicks: 8000000000, Played: false, IsFavorite: true, LastPlayedDate: nil)
        try await queue.acknowledge(old, serverItem: server, serverDate: Date())
        let cached = await queue.latest(account: "a", item: "i")
        XCTAssertEqual(cached?.ticks, 8000000000)
        try await queue.record(account: "a", item: "i", seconds: 900, completed: false, device: "fixture")
        try await queue.acknowledge(old, serverItem: server, serverDate: Date())
        let retained = await queue.latest(account: "a", item: "i")
        XCTAssertEqual(retained?.ticks, 9000000000)
    }
}
