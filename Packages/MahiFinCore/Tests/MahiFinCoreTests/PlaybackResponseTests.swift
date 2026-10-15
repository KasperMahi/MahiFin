import XCTest
@testable import MahiFinCore

final class PlaybackResponseTests: XCTestCase {
    func testServerOfferedConversionIsNeverFollowedImplicitly() async throws {
        let data = try Data(contentsOf: Bundle.module.url(forResource: "playback-info", withExtension: "json", subdirectory: "Fixtures")!)
        let transport = FixtureTransport(data: data)
        let api = try JellyfinClient(server: URL(string: "https://example.invalid")!, token: "fixture", deviceID: "fixture", transport: transport)
        let response = try await api.playbackInfo(user: "fixture", item: "fixture")
        let source = try XCTUnwrap(response.MediaSources.first)
        var capabilities = DeviceCapabilities(); capabilities.alternativeAvailable = true
        XCTAssertEqual(PlaybackPolicy.decide(source, device: capabilities).route, .alternative)
        let request = await transport.last()
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertFalse(request.url!.absoluteString.contains("VideoCodec"))
        let original = try api.directURL(item: "fixture", source: source)
        XCTAssertTrue(original.absoluteString.contains("Static=true"))
        XCTAssertFalse(original.absoluteString.contains("MaxWidth"))
        let diagnostics = DiagnosticReport(source: source, decision: PlaybackPolicy.decide(source, device: capabilities)).export()
        XCTAssertFalse(diagnostics.contains("fixture-secret")); XCTAssertFalse(diagnostics.contains("private"))
    }
}
