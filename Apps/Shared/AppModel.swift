import SwiftUI
import MahiFinCore

@MainActor final class AppModel: ObservableObject {
    @Published var accounts: [Account] = []
    @Published var active: Account?
    @Published var error: String?
    @Published var addingAccount = false
    @Published var diagnostic = DiagnosticReport(source: nil, decision: nil)
    @Published var cellularDownloads = false
    let disk: DiskStore
    let history: HistoryQueue
    let tokens = KeychainTokens()
    let deviceID: String
    private var syncing = false
    #if os(iOS)
    let downloads: DownloadManager
    #endif

    init() throws {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MahiFin")
            disk = try DiskStore(root: root)
            history = try HistoryQueue(disk: disk)
            deviceID = try disk.load(String.self, name: "device.json") ?? UUID().uuidString
            try disk.save(deviceID, name: "device.json")
            #if os(iOS)
            downloads = try DownloadManager(root: root.appendingPathComponent("Downloads"))
            #endif
            accounts = try disk.load([Account].self, name: "accounts.json") ?? []
            let last = try disk.load(String.self, name: "active.json")
            cellularDownloads = try disk.load(Bool.self, name: "cellular.json") ?? false
            #if os(tvOS)
            active = ProfilePolicy.launch(accounts: accounts, last: last, television: true)
            #else
            active = ProfilePolicy.launch(accounts: accounts, last: last, television: false)
            #endif
    }
    func client(for account: Account? = nil) throws -> JellyfinClient {
        guard let selected = account ?? active, let token = try tokens.read(account: selected.id) else { throw ClientError.unauthorized }
        return try JellyfinClient(server: selected.server, token: token, deviceID: deviceID)
    }
    func link(server: URL, info: ServerInfo, auth: AuthResponse) throws {
        let account = Account(server: server, serverID: info.Id, userID: auth.User.Id, name: auth.User.Name)
        try tokens.write(auth.AccessToken, account: account.id)
        var next = accounts.filter { $0.id != account.id }; next.append(account)
        try disk.save(next, name: "accounts.json"); accounts = next
        try select(account); addingAccount = false
    }
    func select(_ account: Account) throws {
        guard accounts.contains(account), try tokens.read(account: account.id) != nil else { throw ClientError.unauthorized }
        try disk.save(account.id, name: "active.json")
        active = account
        Task { await sync() }
    }
    func forget(_ account: Account) async {
        do {
            // Revoke first when reachable, but local logout remains possible offline.
            if let client = try? client(for: account) { try? await client.logout() }
            try tokens.remove(account: account.id)
            let next = accounts.filter { $0.id != account.id }
            try disk.save(next, name: "accounts.json"); accounts = next
            if active?.id == account.id { active = nil }
            #if os(iOS)
            downloads.pause(account: account.id)
            #endif
        } catch { show(error) }
    }
    func show(_ value: Error) {
        // Localized categories only; raw network/server errors may contain signed URLs.
        if let clientError = value as? ClientError { error = clientError.localizedDescription }
        else if value is CancellationError { return }
        else { error = NSLocalizedString("error.network", comment: "") }
    }
    func setCellularDownloads(_ enabled: Bool) {
        do { try disk.save(enabled, name: "cellular.json"); cellularDownloads = enabled }
        catch { show(ClientError.storage) }
    }
    func record(account: Account, item: MediaItem, seconds: Double, completed: Bool) async {
        do { try await history.record(account: account.id, item: item.Id, seconds: seconds, completed: completed, device: deviceID) }
        catch { show(ClientError.storage) }
    }
    func sync() async {
        guard !syncing, let account = active, let api = try? client(for: account) else { return }
        syncing = true; defer { syncing = false }
        let result = await HistorySync.run(queue: history, remote: api, account: account)
        if let issue = result.issue { diagnostic = .init(source: nil, decision: nil, issue: issue) }
    }
}
