import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
public final class URLSessionTransport: NSObject, HTTPTransport, URLSessionTaskDelegate, @unchecked Sendable {
    public override init() { super.init() }
    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        return (data, response)
    }
    public func urlSession(_ session: URLSession, task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void) {
        // Never forward authentication to a different origin or downgrade HTTPS.
        let old = task.originalRequest?.url
        let safe = request.url?.scheme == "https" && request.url?.host == old?.host && request.url?.port == old?.port
        completionHandler(safe ? request : nil)
    }
}
public struct JellyfinClient: Sendable {
    public let server: URL
    public let deviceID: String
    public let token: String?
    private let transport: any HTTPTransport
    public init(server: URL, token: String? = nil, deviceID: String, transport: any HTTPTransport = URLSessionTransport()) throws {
        guard server.scheme?.lowercased() == "https", server.host != nil,
              server.user == nil, server.password == nil, server.query == nil, server.fragment == nil else {
            throw ClientError.invalidServer
        }
        self.server = server; self.token = token; self.deviceID = deviceID; self.transport = transport
    }
    public func url(_ path: String, query: [String: String] = [:]) throws -> URL {
        var components = URLComponents(url: server, resolvingAgainstBaseURL: false)!
        components.path = server.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).isEmpty
            ? "/" + path : server.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).withSlash + path
        components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw ClientError.invalidServer }
        return url
    }
    public func request(_ path: String, method: String = "GET", query: [String: String] = [:], body: Data? = nil) throws -> URLRequest {
        var request = URLRequest(url: try url(path, query: query))
        request.httpMethod = method; request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Header components are constrained; credentials are never interpolated into this header.
        let safeID = deviceID.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        request.setValue("MediaBrowser Client=\"MahiFin\", Device=\"Apple\", DeviceId=\"\(safeID)\", Version=\"0.1.0\"", forHTTPHeaderField: "Authorization")
        if let token { request.setValue(token, forHTTPHeaderField: "X-Emby-Token") }
        return request
    }
    private func execute(_ path: String, method: String = "GET", query: [String: String] = [:], body: Data? = nil) async throws -> Data {
        let (data, response) = try await transport.send(request(path, method: method, query: query, body: body))
        if response.statusCode == 401 || response.statusCode == 403 { throw ClientError.unauthorized }
        guard (200..<300).contains(response.statusCode) else { throw ClientError.http(response.statusCode) }
        return data
    }
    private func get<T: Decodable>(_ type: T.Type, _ path: String, query: [String: String] = [:]) async throws -> T {
        let data = try await execute(path, query: query)
        guard let result = try? JSONDecoder().decode(type, from: data) else { throw ClientError.invalidResponse }
        return result
    }
    public func systemInfo() async throws -> ServerInfo {
        let info = try await get(ServerInfo.self, "System/Info/Public")
        try info.validate(); return info
    }
    public func authenticate(username: String, password: String) async throws -> AuthResponse {
        let body = try JSONSerialization.data(withJSONObject: ["Username": username, "Pw": password])
        let data = try await execute("Users/AuthenticateByName", method: "POST", body: body)
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }
    public func beginQuickConnect() async throws -> QuickConnect {
        guard try await get(Bool.self, "QuickConnect/Enabled") else { throw ClientError.unavailable }
        let data = try await execute("QuickConnect/Initiate", method: "POST")
        return try JSONDecoder().decode(QuickConnect.self, from: data)
    }
    public func pollQuickConnect(secret: String) async throws -> QuickConnect {
        try await get(QuickConnect.self, "QuickConnect/Connect", query: ["secret": secret])
    }
    public func finishQuickConnect(secret: String) async throws -> AuthResponse {
        let data = try await execute("Users/AuthenticateWithQuickConnect", method: "POST",
            body: JSONSerialization.data(withJSONObject: ["Secret": secret]))
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }
    public func logout() async throws { _ = try await execute("Sessions/Logout", method: "POST") }
    public func user(id: String) async throws -> User { try await get(User.self, "Users/\(id)") }
    public func segments(item: String) async throws -> [MediaSegment] {
        do { return try await get(SegmentPage.self, "MediaSegments/\(item)").Items }
        catch ClientError.http(404) { return [] }
    }
    public func items(user: String, route: CatalogRoute, filter: CatalogFilter = .init(), start: Int = 0) async throws -> ItemPage {
        var query = ["UserId": user, "Recursive": "true", "Fields": "Overview,MediaSources,Genres,People", "EnableUserData": "true", "Limit": "60", "StartIndex": String(start)]
        var path = "Items"
        switch route {
        case .resume: path = "Users/\(user)/Items/Resume"; query["MediaTypes"] = "Video"
        case .nextUp: path = "Shows/NextUp"
        case .recent: query["IncludeItemTypes"] = "Movie,Episode"; query["SortBy"] = "DateCreated"; query["SortOrder"] = "Descending"
        case .movies: query["IncludeItemTypes"] = "Movie"
        case .series: query["IncludeItemTypes"] = "Series"
        case .search(let text): query["SearchTerm"] = text; query["IncludeItemTypes"] = "Movie,Series"
        case .children(let parent): query["ParentId"] = parent; query["Recursive"] = "false"; query["SortBy"] = "ParentIndexNumber,IndexNumber"
        case .episodes(let series): path = "Shows/\(series)/Episodes"; query["SortBy"] = "ParentIndexNumber,IndexNumber"
        case .views: path = "Users/\(user)/Views"; query = [:]
        }
        if query["SortBy"] == nil { query["SortBy"] = filter.sort }
        if !filter.genre.isEmpty { query["Genres"] = filter.genre }
        if !filter.year.isEmpty { query["Years"] = filter.year }
        if !filter.library.isEmpty { query["ParentId"] = filter.library }
        if filter.unplayed { query["IsPlayed"] = "false" }
        return try await get(ItemPage.self, path, query: query)
    }
    public func item(user: String, id: String) async throws -> MediaItem {
        try await get(MediaItem.self, "Users/\(user)/Items/\(id)")
    }
    public func setPlayed(user: String, item: String, played: Bool, date: Date? = nil) async throws {
        var query: [String: String] = [:]
        if let date { query["DatePlayed"] = ISO8601DateFormatter().string(from: date) }
        _ = try await execute("Users/\(user)/PlayedItems/\(item)", method: played ? "POST" : "DELETE", query: query)
    }
    public func setFavorite(user: String, item: String, favorite: Bool) async throws {
        _ = try await execute("Users/\(user)/FavoriteItems/\(item)", method: favorite ? "POST" : "DELETE")
    }
    public func playbackInfo(user: String, item: String) async throws -> PlaybackInfo {
        // GET probes metadata only. Never enables transcoding or opens a live source.
        try await get(PlaybackInfo.self, "Items/\(item)/PlaybackInfo", query: ["UserId": user])
    }
    public func originalRequest(item: String) throws -> URLRequest {
        try request("Items/\(item)/Download")
    }
    public func directURL(item: String, source: MediaSource) throws -> URL {
        guard source.IsRemote != true, source.RequiresOpening != true,
              source.VideoType == "VideoFile" else { throw ClientError.unavailable }
        // Token-bearing URL exists only in memory for public AVURLAsset APIs; never persist/export it.
        guard let token else { throw ClientError.unauthorized }
        return try url("Videos/\(item)/stream", query: ["Static": "true", "MediaSourceId": source.Id, "api_key": token])
    }
    public func report(_ event: SessionEvent, endpoint: String) async throws {
        guard ["Playing", "Playing/Progress", "Playing/Stopped"].contains(endpoint) else { throw ClientError.invalidResponse }
        _ = try await execute("Sessions/" + endpoint, method: "POST", body: JSONEncoder().encode(event))
    }
    public func savePosition(user: String, item: String, ticks: Int64, date: Date? = nil, completed: Bool = false) async throws {
        var values: [String: Any] = ["PlaybackPositionTicks": completed ? 0 : ticks]
        if let date {
            let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            values["LastPlayedDate"] = formatter.string(from: date)
        }
        // Absolute state is idempotent. No play-count increment on retry and no unrelated field writes.
        if completed { values["Played"] = true }
        let body = try JSONSerialization.data(withJSONObject: values)
        _ = try await execute("UserItems/\(item)/UserData", method: "POST", query: ["UserId": user], body: body)
    }
    public func artwork(item: MediaItem) throws -> URLRequest? {
        guard let tag = item.ImageTags?["Primary"] else { return nil }
        return try request("Items/\(item.Id)/Images/Primary", query: ["Tag": tag, "MaxWidth": "400", "Quality": "85"])
    }
    func sendNoContent(_ path: String, method: String, query: [String: String]) async throws {
        _ = try await execute(path, method: method, query: query)
    }
}
private extension String { var withSlash: String { "/" + self + "/" } }
