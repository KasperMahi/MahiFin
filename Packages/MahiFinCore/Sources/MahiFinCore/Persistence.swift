import Foundation

public protocol Clock: Sendable { func now() -> Date }
public struct SystemClock: Clock { public init() {} ; public func now() -> Date { Date() } }
public protocol TokenStore: Sendable {
    func read(account: String) throws -> String?
    func write(_ token: String, account: String) throws
    func remove(account: String) throws
}
public struct DiskStore: Sendable {
    public let root: URL
    public init(root: URL) throws {
        self.root = root
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    public func load<T: Decodable>(_ type: T.Type, name: String) throws -> T? {
        let url = root.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }
    public func save<T: Encodable>(_ value: T, name: String) throws {
        let url = root.appendingPathComponent(name)
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
        #if os(iOS) || os(tvOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
        #endif
        var protected = url
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try protected.setResourceValues(values)
    }
}
public enum ProfilePolicy {
    public static func launch(accounts: [Account], last: String?, television: Bool) -> Account? {
        guard !television else { return nil }
        return accounts.first { $0.id == last } ?? accounts.first
    }
}
public struct HistoryEvent: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var account: String
    public var item: String
    public var ticks: Int64
    public var completed: Bool
    public var occurred: Date
    public var sequence: Int64
    public var device: String
    public init(account: String, item: String, ticks: Int64, completed: Bool, occurred: Date, sequence: Int64, device: String, id: UUID = UUID()) {
        self.id = id; self.account = account; self.item = item; self.ticks = ticks; self.completed = completed
        self.occurred = occurred; self.sequence = sequence; self.device = device
    }
    public static func newer(_ lhs: HistoryEvent, _ rhs: HistoryEvent) -> Bool {
        if lhs.device == rhs.device { return lhs.sequence > rhs.sequence }
        if lhs.occurred != rhs.occurred { return lhs.occurred > rhs.occurred }
        if lhs.device != rhs.device { return lhs.device > rhs.device }
        return lhs.id.uuidString > rhs.id.uuidString
    }
}
public actor HistoryQueue {
    private let disk: DiskStore
    private var events: [HistoryEvent]
    private var sequence: Int64
    public init(disk: DiskStore) throws {
        self.disk = disk
        events = try disk.load([HistoryEvent].self, name: "history.json") ?? []
        sequence = try disk.load(Int64.self, name: "sequence.json") ?? 0
    }
    public func record(account: String, item: String, seconds: Double, completed: Bool, device: String, clock: any Clock = SystemClock()) throws {
        sequence += 1
        try disk.save(sequence, name: "sequence.json")
        let event = HistoryEvent(account: account, item: item, ticks: SessionEvent.ticks(seconds), completed: completed, occurred: clock.now(), sequence: sequence, device: device)
        events.removeAll { $0.account == account && $0.item == item }
        events.append(event); try persist()
    }
    public func pending(account: String) -> [HistoryEvent] {
        events.filter { $0.account == account }.sorted { $0.sequence < $1.sequence }
    }
    public func acknowledge(_ event: HistoryEvent) throws {
        events.removeAll { $0.id == event.id }; try persist()
    }
    private func persist() throws { try disk.save(events, name: "history.json") }
}
public enum SyncResolution: Equatable { case upload, discard, conflict }
public enum HistoryConflict {
    public static func resolve(_ event: HistoryEvent, serverDate: Date?, now: Date) -> SyncResolution {
        // Future dates or clock ambiguity do not authorize overwriting server history.
        if event.occurred > now.addingTimeInterval(120) || (serverDate ?? .distantPast) > now.addingTimeInterval(120) { return .conflict }
        guard let serverDate else { return .upload }
        if serverDate == event.occurred { return .conflict }
        return serverDate > event.occurred ? .discard : .upload
    }
}
public enum DownloadState: String, Codable, Sendable { case queued, downloading, paused, failed, complete }
public struct DownloadRecord: Codable, Identifiable, Sendable {
    public var id: UUID
    public var account: String
    public var item: MediaItem
    public var source: MediaSource
    public var state: DownloadState
    public var received: Int64
    public var expected: Int64
    public var filename: String?
    public var taskID: Int?
    public var failure: String?
    public init(account: String, item: MediaItem, source: MediaSource) {
        id = UUID(); self.account = account; self.item = item; self.source = source
        state = .queued; received = 0; expected = source.Size ?? 0
    }
    public func localURL(root: URL, activeAccount: String) throws -> URL {
        guard account == activeAccount, state == .complete, let filename,
              filename == URL(fileURLWithPath: filename).lastPathComponent,
              filename.hasPrefix(id.uuidString + ".") else { throw ClientError.unavailable }
        return root.appendingPathComponent(filename)
    }
}
public protocol CastController: Sendable {
    func status() async -> CastStatus
    func load(_ item: MediaItem, decision: PlaybackDecision) async throws
    func pause() async throws
    func seek(seconds: Double) async throws
}
public enum CastStatus: Equatable, Sendable { case unavailable, disconnected, connected, playing }
public struct UnavailableCast: CastController {
    public init() {}
    public func status() async -> CastStatus { .unavailable }
    public func load(_ item: MediaItem, decision: PlaybackDecision) async throws { throw ClientError.unavailable }
    public func pause() async throws { throw ClientError.unavailable }
    public func seek(seconds: Double) async throws { throw ClientError.unavailable }
}
