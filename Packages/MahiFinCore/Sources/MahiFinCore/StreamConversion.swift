import Foundation

public enum ConversionMode: String, Sendable { case remux, audioOnly, video }
public enum EnginePreference: String, Codable, CaseIterable, Sendable { case automatic, native, alternative }

/// An explicit, short-lived approval for one account/item/source, never a stored global setting.
public struct VideoConsent: Sendable {
    let account: String
    let item: String
    let source: String
    let accepted: Date
    public static func accept(account: String, item: String, source: String, clock: any Clock = SystemClock()) -> VideoConsent {
        .init(account: account, item: item, source: source, accepted: clock.now())
    }
    public func permits(account: String, item: String, source: String, now: Date) -> Bool {
        self.account == account && self.item == item && self.source == source
            && now >= accepted && now.timeIntervalSince(accepted) <= 300
    }
}
public struct PendingVideoConsent: Identifiable, Sendable {
    public let id = UUID()
    public let account: String
    public let item: String
    public let source: String
    public init(account: String, item: String, source: String) { self.account = account; self.item = item; self.source = source }
}
extension JellyfinClient {
    public func conversionURL(account: Account, item: String, source: MediaSource, session: String, mode: ConversionMode, consent: VideoConsent? = nil, clock: any Clock = SystemClock()) throws -> URL {
        guard source.VideoType == "VideoFile", source.IsRemote != true, source.RequiresOpening != true,
              account.server == server, let token else { throw ClientError.unavailable }
        if mode == .video {
            guard consent?.permits(account: account.id, item: item, source: source.Id, now: clock.now()) == true else { throw ClientError.unavailable }
        }
        var query = [
            "UserId": account.userID, "DeviceId": deviceID, "MediaSourceId": source.Id, "PlaySessionId": session,
            "api_key": token, "VideoCodec": mode == .video ? "h264" : "copy",
            "AudioCodec": mode == .remux ? "copy" : "aac", "SegmentContainer": "fmp4",
            "AllowVideoStreamCopy": "true", "AllowAudioStreamCopy": mode == .remux ? "true" : "false",
            "EnableAutoStreamCopy": "true", "SubtitleStreamIndex": "-1", "SubtitleMethod": "External",
            "AlwaysBurnInSubtitleWhenTranscoding": "false"
        ]
        if let index = source.selectedAudio?.Index { query["AudioStreamIndex"] = String(index) }
        if mode == .video { query["MaxWidth"] = "1920"; query["MaxHeight"] = "1080"; query["VideoBitRate"] = "8000000" }
        // Copy is an explicit ffmpeg video codec in the audited 10.10 API, not merely permission to copy.
        // No video sizing/rate/deinterlace/tone-map constraint is ever added for remux/audio-only.
        return try url("Videos/\(item)/master.m3u8", query: query)
    }
    public func stopConversion(session: String) async throws {
        try await sendNoContent("Videos/ActiveEncodings", method: "DELETE", query: ["DeviceId": deviceID, "PlaySessionId": session])
    }
}
