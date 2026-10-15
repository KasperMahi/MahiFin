import XCTest
@testable import MahiFinCore

final class ConversionTests: XCTestCase {
    let account = Account(server: URL(string: "https://example.invalid")!, serverID: "s", userID: "u", name: "Invented")
    func source() -> MediaSource { .init(id: "source", container: "mkv", streams: [.init(type: "Video", codec: "h264", width: 3840), .init(type: "Audio", codec: "truehd")]) }
    func testCopyModesNeverAuthorizeVideoEncodingOrBurnIn() throws {
        let api = try JellyfinClient(server: account.server, token: "fixture", deviceID: "fixture")
        for mode in [ConversionMode.remux, .audioOnly] {
            let url = try api.conversionURL(account: account, item: "i", source: source(), session: "fixture", mode: mode)
            let query = Dictionary(uniqueKeysWithValues: URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value!) })
            XCTAssertEqual(query["VideoCodec"], "copy")
            XCTAssertEqual(query["AudioCodec"], mode == .remux ? "copy" : "aac")
            XCTAssertEqual(query["SegmentContainer"], "mp4")
            XCTAssertEqual(query["SubtitleStreamIndex"], "-1"); XCTAssertEqual(query["SubtitleMethod"], "External")
            XCTAssertEqual(query["AlwaysBurnInSubtitleWhenTranscoding"], "false")
            XCTAssertNil(query["MaxWidth"]); XCTAssertNil(query["VideoBitRate"])
        }
    }
    func testConsentIsScopedExpiringAndNeverImplicit() throws {
        let api = try JellyfinClient(server: account.server, token: "fixture", deviceID: "fixture")
        let now = FixedClock(value: Date(timeIntervalSince1970: 1000))
        let grant = VideoConsent.accept(account: account.id, item: "i", source: "source", clock: now)
        XCTAssertThrowsError(try api.conversionURL(account: account, item: "i", source: source(), session: "s", mode: .video))
        XCTAssertThrowsError(try api.conversionURL(account: account, item: "other", source: source(), session: "s", mode: .video, consent: grant, clock: now))
        XCTAssertThrowsError(try api.conversionURL(account: account, item: "i", source: source(), session: "s", mode: .video, consent: grant, clock: FixedClock(value: now.value.addingTimeInterval(301))))
        let url = try api.conversionURL(account: account, item: "i", source: source(), session: "s", mode: .video, consent: grant, clock: now)
        XCTAssertTrue(url.absoluteString.contains("VideoCodec=h264"))
    }
}
