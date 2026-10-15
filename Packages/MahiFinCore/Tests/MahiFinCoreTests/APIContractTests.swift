import XCTest
@testable import MahiFinCore
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

actor QuickConnectTransport: HTTPTransport {
    private var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let json: String
        switch request.url!.lastPathComponent {
        case "Enabled": json = "true"
        case "Initiate": json = "{\"Secret\":\"fixture-secret\",\"Code\":\"123456\",\"Authenticated\":false}"
        case "Connect": json = "{\"Secret\":\"fixture-secret\",\"Code\":\"123456\",\"Authenticated\":true}"
        case "AuthenticateWithQuickConnect": json = "{\"AccessToken\":\"fixture-token\",\"User\":{\"Id\":\"u\",\"Name\":\"Invented\"}}"
        default: throw ClientError.invalidResponse
        }
        return (Data(json.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
    func snapshot() -> [URLRequest] { requests }
}
struct DelayedTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await Task.sleep(for: .seconds(5))
        throw ClientError.invalidResponse
    }
}
final class APIContractTests: XCTestCase {
    func client(_ transport: any HTTPTransport) throws -> JellyfinClient {
        try .init(server: URL(string: "https://example.invalid")!, token: "fixture-token", deviceID: "fixture", transport: transport)
    }
    func testQuickConnectEndpointSequence() async throws {
        let transport = QuickConnectTransport(); let api = try client(transport)
        let initial = try await api.beginQuickConnect()
        XCTAssertEqual(initial.Code, "123456"); XCTAssertFalse(initial.Authenticated)
        let authorized = try await api.pollQuickConnect(secret: initial.Secret)
        XCTAssertTrue(authorized.Authenticated)
        let auth = try await api.finishQuickConnect(secret: initial.Secret)
        XCTAssertEqual(auth.User.Id, "u")
        let requests = await transport.snapshot()
        XCTAssertEqual(requests.map(\.httpMethod), ["GET", "POST", "GET", "POST"])
        XCTAssertEqual(requests.map { $0.url!.path }, ["/QuickConnect/Enabled", "/QuickConnect/Initiate", "/QuickConnect/Connect", "/Users/AuthenticateWithQuickConnect"])
        let body = try JSONSerialization.jsonObject(with: requests.last!.httpBody!) as! [String: String]
        XCTAssertEqual(body, ["Secret": "fixture-secret"])
        XCTAssertFalse(requests.last!.url!.absoluteString.contains("fixture-secret"))
    }
    func testFilterPaginationAndIndependentMutations() async throws {
        let transport = FixtureTransport("{\"Items\":[],\"TotalRecordCount\":0}")
        let api = try client(transport)
        var filter = CatalogFilter(); filter.genre = "Drama"; filter.year = "2024"; filter.library = "library"; filter.unplayed = true
        _ = try await api.items(user: "u", route: .movies, filter: filter, start: 60)
        let request = await transport.last()
        let query = Dictionary(uniqueKeysWithValues: URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value!) })
        XCTAssertEqual(query["StartIndex"], "60"); XCTAssertEqual(query["IncludeItemTypes"], "Movie")
        XCTAssertEqual(query["Genres"], "Drama"); XCTAssertEqual(query["Years"], "2024")
        XCTAssertEqual(query["ParentId"], "library"); XCTAssertEqual(query["IsPlayed"], "false")
        try await api.setFavorite(user: "u", item: "i", favorite: false)
        let favorite = await transport.last()
        XCTAssertEqual(favorite.httpMethod, "DELETE"); XCTAssertEqual(favorite.url?.path, "/Users/u/FavoriteItems/i")
        try await api.setPlayed(user: "u", item: "i", played: true)
        let played = await transport.last()
        XCTAssertEqual(played.httpMethod, "POST"); XCTAssertEqual(played.url?.path, "/Users/u/PlayedItems/i")
    }
    func testAuthOperationPropagatesCancellation() async throws {
        let api = try client(DelayedTransport())
        let task = Task { try await api.authenticate(username: "Invented", password: "fixture") }
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled auth must not succeed") }
        catch { XCTAssertTrue(error is CancellationError) }
    }
}
