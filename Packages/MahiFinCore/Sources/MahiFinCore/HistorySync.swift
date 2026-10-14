import Foundation

public protocol HistoryRemote: Sendable {
    func item(user: String, id: String) async throws -> MediaItem
    func savePosition(user: String, item: String, ticks: Int64, date: Date?, completed: Bool) async throws
}
extension JellyfinClient: HistoryRemote {}

public struct HistorySyncResult: Equatable, Sendable {
    public var acknowledged: Int
    public var issue: String?
}
public enum HistorySync {
    public static func serverDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
    public static func run(queue: HistoryQueue, remote: any HistoryRemote, account: Account, clock: any Clock = SystemClock()) async -> HistorySyncResult {
        var acknowledged = 0
        for event in await queue.pending(account: account.id) {
            do {
                try Task.checkCancellation()
                let current = try await remote.item(user: account.userID, id: event.item)
                let date = serverDate(current.UserData?.LastPlayedDate)
                let applied = date.map { abs($0.timeIntervalSince(event.occurred)) < 0.001 } == true
                    && (event.completed ? current.UserData?.Played == true : current.UserData?.PlaybackPositionTicks == event.ticks)
                if !applied {
                    let resolution = HistoryConflict.resolve(event, serverDate: date, now: clock.now())
                    if resolution == .conflict { return .init(acknowledged: acknowledged, issue: "conflict") }
                    if resolution == .upload {
                        try await remote.savePosition(user: account.userID, item: event.item, ticks: event.ticks, date: event.occurred, completed: event.completed)
                    }
                }
                // UUID-based acknowledgement cannot remove a newer activity recorded during this request.
                try await queue.acknowledge(event); acknowledged += 1
            } catch {
                return .init(acknowledged: acknowledged, issue: (error as? ClientError) == .unauthorized ? "auth" : "network")
            }
        }
        return .init(acknowledged: acknowledged, issue: nil)
    }
}
