import XCTest
@testable import MahiFinCore

final class HDRPolicyTests: XCTestCase {
    func testNativeHDRRequiresActualModeAndKnownMain10Metadata() {
        var video = MediaStream(type: "Video", codec: "hevc", width: 3840, range: "HDR10")
        video.Profile = "Main 10"; video.BitDepth = 10
        var source = MediaSource(id: "fixture", container: "mp4", streams: [video, .init(type: "Audio", codec: "aac")])
        var device = DeviceCapabilities()
        XCTAssertEqual(PlaybackPolicy.decide(source, device: device).route, .unsupported)
        device.hdrFormats = ["HDR10"]
        XCTAssertEqual(PlaybackPolicy.decide(source, device: device).route, .direct)
        source.Container = "mkv"; device.alternativeAvailable = true
        XCTAssertEqual(PlaybackPolicy.decide(source, device: device).route, .remux)
        video.VideoRangeType = "DOVIWithHDR10"; source.MediaStreams = [video]
        XCTAssertEqual(PlaybackPolicy.decide(source, device: device).route, .unsupported)
        video.VideoRangeType = "HDR10"; video.BitDepth = 8; video.Profile = "Main"; source.MediaStreams = [video]
        XCTAssertEqual(PlaybackPolicy.decide(source, device: device).route, .unsupported)
    }
}
