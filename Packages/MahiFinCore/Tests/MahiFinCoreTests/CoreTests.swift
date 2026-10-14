import XCTest
@testable import MahiFinCore
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

actor FixtureTransport: HTTPTransport {
    var requests: [URLRequest] = []
    let data: Data
    let status: Int
    init(_ string: String, status: Int = 200) { data = Data(string.utf8); self.status = status }
    init(data: Data) { self.data = data; status = 200 }
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        return (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
    func last() -> URLRequest { requests.last! }
}
final class CoreTests: XCTestCase {
    func client(_ fixture: FixtureTransport) throws -> JellyfinClient {
        try JellyfinClient(server: URL(string: "https://example.invalid/jellyfin")!, token: "fixture-token", deviceID: "test", transport: fixture)
    }
    func testCatalogFixtureAndBasePath() async throws {
        let data = try Data(contentsOf: Bundle.module.url(forResource: "items", withExtension: "json", subdirectory: "Fixtures")!)
        let transport = FixtureTransport(data: data)
        let page = try await client(transport).items(user: "test-user", route: .resume)
        XCTAssertEqual(page.Items.first?.position, 720)
        let request = await transport.last()
        XCTAssertEqual(request.url?.path, "/jellyfin/Users/test-user/Items/Resume")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Emby-Token"), "fixture-token")
        XCTAssertFalse(request.url!.absoluteString.contains("fixture-token"))
    }
    func testAuthenticationJSON() async throws {
        let transport = FixtureTransport("{\"AccessToken\":\"test\",\"User\":{\"Id\":\"u\",\"Name\":\"Invented\"}}")
        _ = try await client(transport).authenticate(username: "Invented", password: "fixture")
        let request = await transport.last()
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: String]
        XCTAssertEqual(body["Pw"], "fixture")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/jellyfin/Users/AuthenticateByName")
    }
    func testHTTPFailuresAndHandshake() async throws {
        do { _ = try await client(FixtureTransport("{}", status: 401)).systemInfo(); XCTFail("Expected unauthorized") }
        catch { XCTAssertEqual(error as? ClientError, .unauthorized) }
        do { _ = try await client(FixtureTransport("{\"Id\":\"s\",\"Version\":\"10.8.13\"}")).systemInfo(); XCTFail("Expected old version rejection") }
        catch { XCTAssertEqual(error as? ClientError, .unsupportedServer) }
        XCTAssertThrowsError(try JellyfinClient(server: URL(string: "http://example.invalid")!, deviceID: "test"))
        XCTAssertThrowsError(try JellyfinClient(server: URL(string: "https://user:pass@example.invalid")!, deviceID: "test"))
    }
    func testPositionUpdatePreservesUnrelatedFields() async throws {
        let transport = FixtureTransport("{}")
        try await client(transport).savePosition(user: "u", item: "i", ticks: 7200000000, date: Date(timeIntervalSince1970: 1000))
        let request = await transport.last()
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        XCTAssertEqual(request.url?.path, "/jellyfin/UserItems/i/UserData")
        XCTAssertEqual(body["PlaybackPositionTicks"] as? Int64, 7200000000)
        XCTAssertNotNil(body["LastPlayedDate"])
        XCTAssertNil(body["IsFavorite"]); XCTAssertNil(body["Played"]); XCTAssertNil(body["PlayCount"])
        try await client(transport).savePosition(user: "u", item: "i", ticks: 100, completed: true)
        let completed = await transport.last()
        let values = try JSONSerialization.jsonObject(with: completed.httpBody!) as! [String: Any]
        XCTAssertEqual(values["Played"] as? Bool, true)
        XCTAssertEqual(values["PlaybackPositionTicks"] as? Int, 0)
        XCTAssertNil(values["PlayCount"])
    }
    func source(container: String = "mp4", video: String = "h264", audio: String = "aac", width: Int = 1920) -> MediaSource {
        MediaSource(id: "fixture", container: container, streams: [.init(type: "Video", codec: video, width: width, range: "SDR"), .init(type: "Audio", codec: audio)])
    }
    func testPlaybackPolicyNeverSilentlyConvertsVideo() {
        XCTAssertEqual(PlaybackPolicy.decide(source(), device: .init()).route, .direct)
        XCTAssertEqual(PlaybackPolicy.decide(source(container: "mkv"), device: .init()).route, .remux)
        var device = DeviceCapabilities(); device.alternativeAvailable = true
        XCTAssertEqual(PlaybackPolicy.decide(source(container: "mkv"), device: device).route, .alternative)
        XCTAssertEqual(PlaybackPolicy.decide(source(audio: "truehd"), device: .init()).route, .audioOnly)
        XCTAssertEqual(PlaybackPolicy.decide(source(), device: .init(), requiresSubtitleBurnIn: true).route, .needsVideoConsent)
        XCTAssertEqual(PlaybackPolicy.decide(source(video: "hevc", width: 3840), device: .legacyCast).route, .needsVideoConsent)
        XCTAssertEqual(PlaybackPolicy.decide(source(width: 3840), device: .init()).route, .direct)
        XCTAssertFalse(PlaybackPolicy.decide(source(video: "unknown"), device: .init()).canStart)
    }
    func testOriginalRequestsNeverNegotiateConversion() throws {
        let value = try client(FixtureTransport("{}"))
        let url = try value.directURL(item: "fixture", source: source())
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertEqual(query.first { $0.name == "Static" }?.value, "true")
        XCTAssertFalse(url.absoluteString.contains("VideoCodec"))
        XCTAssertEqual(try value.originalRequest(item: "fixture").url?.path, "/jellyfin/Items/fixture/Download")
    }
    func testProfileLaunchPolicy() {
        let a = Account(server: URL(string: "https://example.invalid")!, serverID: "s", userID: "a", name: "A")
        let b = Account(server: a.server, serverID: "s", userID: "b", name: "B")
        XCTAssertNil(ProfilePolicy.launch(accounts: [a,b], last: b.id, television: true))
        XCTAssertEqual(ProfilePolicy.launch(accounts: [a,b], last: b.id, television: false), b)
    }
    func testHistoryPersistenceCoalescingAndIsolation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let disk = try DiskStore(root: root)
        let queue = try HistoryQueue(disk: disk)
        try await queue.record(account: "a", item: "movie", seconds: 720, completed: false, device: "d")
        try await queue.record(account: "a", item: "movie", seconds: 730, completed: false, device: "d")
        try await queue.record(account: "b", item: "movie", seconds: 10, completed: false, device: "d")
        let restored = try HistoryQueue(disk: disk)
        let a = await restored.pending(account: "a")
        XCTAssertEqual(a.count, 1); XCTAssertEqual(a[0].ticks, 7300000000)
        try await restored.acknowledge(a[0])
        try await restored.acknowledge(a[0])
        let remainingA = await restored.pending(account: "a")
        let remainingB = await restored.pending(account: "b")
        XCTAssertTrue(remainingA.isEmpty); XCTAssertEqual(remainingB.count, 1)
    }
    func testConflictsAndClockSkew() {
        let now = Date(timeIntervalSince1970: 1000)
        let event = HistoryEvent(account: "a", item: "i", ticks: 100, completed: false, occurred: now, sequence: 1, device: "d")
        XCTAssertEqual(HistoryConflict.resolve(event, serverDate: now.addingTimeInterval(10), now: now), .discard)
        XCTAssertEqual(HistoryConflict.resolve(event, serverDate: now.addingTimeInterval(-10), now: now), .upload)
        XCTAssertEqual(HistoryConflict.resolve(event, serverDate: now.addingTimeInterval(300), now: now), .conflict)
        XCTAssertEqual(HistoryConflict.resolve(event, serverDate: now, now: now), .conflict)
    }
    func testNextEpisodeAndNonfinitePosition() {
        var countdown = NextCountdown()
        for _ in 0..<4 { XCTAssertFalse(countdown.tick()) }
        XCTAssertTrue(countdown.tick()); XCTAssertFalse(countdown.tick())
        var cancelled = NextCountdown(); cancelled.cancel()
        for _ in 0..<8 { XCTAssertFalse(cancelled.tick()) }
        XCTAssertEqual(SessionEvent.ticks(.nan), 0)
        XCTAssertEqual(SessionEvent.ticks(.infinity), 0)
    }
    func testTrustedSegmentsOnly() throws {
        let json = "{\"Id\":\"s\",\"ItemId\":\"i\",\"Type\":\"Intro\",\"StartTicks\":100000000,\"EndTicks\":200000000}"
        let segment = try JSONDecoder().decode(MediaSegment.self, from: Data(json.utf8))
        XCTAssertTrue(segment.active(item: "i", seconds: 15))
        XCTAssertFalse(segment.active(item: "other", seconds: 15))
        XCTAssertFalse(segment.active(item: "i", seconds: 20))
        XCTAssertFalse(segment.active(item: "i", seconds: .nan))
        var invalid = segment; invalid.EndTicks = 0
        XCTAssertFalse(invalid.active(item: "i", seconds: 15))
    }
    func testDiagnosticsAllowlistAndOfflineIsolation() throws {
        let secret = "https://private.invalid/title?api_key=secret"
        let badSource = MediaSource(id: secret, container: secret, streams: [.init(type: "Video", codec: secret)])
        let exported = DiagnosticReport(source: badSource, decision: nil, issue: secret).export()
        XCTAssertFalse(exported.contains("secret")); XCTAssertFalse(exported.contains("private")); XCTAssertFalse(exported.contains("https"))
        var download = DownloadRecord(account: "a", item: .init(id: "i", name: "Invented"), source: source())
        download.state = .complete; download.filename = download.id.uuidString + ".mp4"
        XCTAssertThrowsError(try download.localURL(root: URL(fileURLWithPath: "/tmp"), activeAccount: "b"))
        download.filename = "../escape.mp4"
        XCTAssertThrowsError(try download.localURL(root: URL(fileURLWithPath: "/tmp"), activeAccount: "a"))
    }
}
