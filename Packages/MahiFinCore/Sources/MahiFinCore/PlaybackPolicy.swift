import Foundation

public enum PlaybackRoute: String, Codable, Sendable {
    case direct, alternative, remux, audioOnly, needsVideoConsent, unsupported
}
public struct PlaybackDecision: Equatable, Sendable {
    public var route: PlaybackRoute
    public var reason: String
    public var canStart: Bool { route == .direct || route == .alternative }
}
public struct DeviceCapabilities: Sendable {
    public var nativeContainers: Set<String> = ["mp4", "mov", "m4v"]
    public var videoCodecs: Set<String> = ["h264", "hevc"]
    public var audioCodecs: Set<String> = ["aac", "ac3", "eac3", "alac", "mp3"]
    public var maxWidth: Int = 4096
    public var alternativeAvailable = false
    public var hdrAvailable = false
    public init() {}
    public static var legacyCast: DeviceCapabilities {
        var value = DeviceCapabilities()
        value.videoCodecs = ["h264"]; value.audioCodecs = ["aac", "mp3"]; value.maxWidth = 1920
        return value
    }
}
public enum PlaybackPolicy {
    public static func decide(_ source: MediaSource, device: DeviceCapabilities, requiresSubtitleBurnIn: Bool = false) -> PlaybackDecision {
        func decision(_ route: PlaybackRoute, _ reason: String) -> PlaybackDecision { .init(route: route, reason: reason) }
        guard source.IsRemote != true, source.RequiresOpening != true,
              source.VideoType == nil || source.VideoType == "VideoFile" else { return decision(.unsupported, "source") }
        guard let streams = source.MediaStreams, let video = streams.first(where: { $0.Type == "Video" }),
              let codec = video.Codec?.lowercased(), let width = video.Width, width > 0 else { return decision(.unsupported, "metadata") }
        if requiresSubtitleBurnIn { return decision(.needsVideoConsent, "subtitles") }
        if !device.videoCodecs.contains(codec) || width > device.maxWidth { return decision(.needsVideoConsent, "video") }
        let hdr = video.VideoRangeType.map { !["SDR", "Unknown"].contains($0) } ?? false
        if hdr && !device.hdrAvailable { return decision(.unsupported, "hdr.hardware") }
        let container = source.Container?.lowercased() ?? ""
        let audio = streams.filter { $0.Type == "Audio" }
        let audioSupported = audio.isEmpty || audio.allSatisfy { device.audioCodecs.contains($0.Codec?.lowercased() ?? "") }
        if !device.nativeContainers.contains(container) {
            return device.alternativeAvailable ? decision(.alternative, "container.local") : decision(.remux, "container")
        }
        if !audioSupported { return decision(.audioOnly, "audio") }
        return decision(.direct, "original")
    }
}
public struct SessionEvent: Codable, Sendable {
    public var ItemId: String
    public var MediaSourceId: String?
    public var PlaySessionId: String
    public var PositionTicks: Int64
    public var IsPaused: Bool
    public var CanSeek = true
    public var PlayMethod = "DirectPlay"
    public init(item: String, source: String?, session: String, seconds: Double, paused: Bool) {
        ItemId = item; MediaSourceId = source; PlaySessionId = session
        PositionTicks = Self.ticks(seconds); IsPaused = paused
    }
    public static func ticks(_ seconds: Double) -> Int64 {
        guard seconds.isFinite, seconds > 0 else { return 0 }
        return Int64(min(seconds * 10_000_000, Double(Int64.max - 1024)))
    }
}
public struct NextCountdown: Equatable, Sendable {
    public private(set) var remaining = 5
    public private(set) var cancelled = false
    public init() {}
    public mutating func cancel() { cancelled = true }
    public mutating func tick() -> Bool {
        guard !cancelled, remaining > 0 else { return false }
        remaining -= 1; return remaining == 0
    }
}
public struct DiagnosticReport: Codable, Sendable {
    public var route: String
    public var video: String
    public var audio: String
    public var container: String
    public var issue: String
    public init(source: MediaSource?, decision: PlaybackDecision?, issue: String = "none") {
        // Never accept free-form server error messages, URLs, item titles or identifiers.
        let codecs: Set<String> = ["h264", "hevc", "aac", "ac3", "eac3", "alac", "mp3", "dts", "truehd", "opus"]
        let videoCodec = source?.MediaStreams?.first(where: { $0.Type == "Video" })?.Codec?.lowercased()
        let audioCodec = source?.MediaStreams?.first(where: { $0.Type == "Audio" })?.Codec?.lowercased()
        video = videoCodec.flatMap { codecs.contains($0) ? $0 : nil } ?? "unknown"
        audio = audioCodec.flatMap { codecs.contains($0) ? $0 : nil } ?? "unknown"
        let containers: Set<String> = ["mp4", "mkv", "mov", "m4v", "ts", "webm"]
        container = source?.Container.flatMap { containers.contains($0) ? $0 : nil } ?? "unknown"
        route = decision?.route.rawValue ?? "unknown"
        self.issue = ["none", "network", "auth", "player", "unsupported", "storage", "conflict"].contains(issue) ? issue : "unknown"
    }
    public func export() -> String { String(data: (try? JSONEncoder().encode(self)) ?? Data(), encoding: .utf8) ?? "{}" }
}
