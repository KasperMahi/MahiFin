import XCTest
@testable import MahiFinCore

final class AudioRouteTests: XCTestCase {
    func testUnusedIncompatibleAudioNeverTriggersConversion() throws {
        var aac = MediaStream(type: "Audio", codec: "aac"); aac.Index = 1; aac.IsDefault = true
        var truehd = MediaStream(type: "Audio", codec: "truehd"); truehd.Index = 2
        var source = MediaSource(id: "fixture", container: "mp4", streams: [.init(type: "Video", codec: "h264", width: 1920), aac, truehd])
        XCTAssertEqual(PlaybackPolicy.decide(source, device: .init()).route, .direct)
        source.DefaultAudioStreamIndex = 2
        XCTAssertEqual(PlaybackPolicy.decide(source, device: .init()).route, .audioOnly)
        XCTAssertEqual(DiagnosticReport(source: source, decision: PlaybackPolicy.decide(source, device: .init())).audio, "truehd")
        let server = URL(string: "https://example.invalid")!
        let account = Account(server: server, serverID: "s", userID: "u", name: "Invented")
        let api = try JellyfinClient(server: server, token: "fixture", deviceID: "fixture")
        let url = try api.conversionURL(account: account, item: "fixture", source: source, session: "fixture", mode: .audioOnly)
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertEqual(query.first(where: { $0.name == "AudioStreamIndex" })?.value, "2")
        XCTAssertEqual(query.first(where: { $0.name == "VideoCodec" })?.value, "copy")
    }
}
