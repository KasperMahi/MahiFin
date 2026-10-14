import Foundation

public enum ClientError: Error, Equatable, LocalizedError {
    case invalidServer, unsupportedServer, unauthorized, http(Int), invalidResponse, unavailable, conflict, storage
    public var errorDescription: String? {
        let key: String
        switch self {
        case .invalidServer: key = "error.server"
        case .unsupportedServer: key = "error.version"
        case .unauthorized: key = "error.auth"
        case .http: key = "error.http"
        case .invalidResponse: key = "error.response"
        case .unavailable: key = "error.unavailable"
        case .conflict: key = "error.conflict"
        case .storage: key = "error.storage"
        }
        return NSLocalizedString(key, comment: "Client error")
    }
}

public struct ServerInfo: Codable, Sendable {
    public var Id: String
    public var Version: String
    public var ServerName: String?
    public func validate() throws {
        let parts = Version.split(separator: ".").compactMap { Int($0) }
        guard parts.count >= 2, parts[0] > 10 || (parts[0] == 10 && parts[1] >= 10) else {
            throw ClientError.unsupportedServer
        }
    }
}
public struct User: Codable, Sendable {
    public var Id: String
    public var Name: String
    public var Configuration: UserPreferences?
}
public struct UserPreferences: Codable, Sendable {
    public var AudioLanguagePreference: String?
    public var PlayDefaultAudioTrack: Bool?
    public var SubtitleLanguagePreference: String?
    public var SubtitleMode: String?
}
public struct MediaSegment: Codable, Identifiable, Sendable {
    public var id: String { Id }
    public var Id: String
    public var ItemId: String
    public var `Type`: String
    public var StartTicks: Int64
    public var EndTicks: Int64
    public func active(item: String, seconds: Double) -> Bool {
        guard ItemId == item, ["Intro", "Outro"].contains(Type), StartTicks >= 0, EndTicks > StartTicks, seconds.isFinite else { return false }
        let ticks = SessionEvent.ticks(seconds)
        return ticks >= StartTicks && ticks < EndTicks
    }
}
public struct SegmentPage: Codable, Sendable { public var Items: [MediaSegment] }
public struct AuthResponse: Codable, Sendable {
    public var AccessToken: String
    public var User: User
}
public struct QuickConnect: Codable, Sendable {
    public var Secret: String
    public var Code: String
    public var Authenticated: Bool
}
public struct Account: Codable, Identifiable, Equatable, Sendable {
    public var id: String { serverID + ":" + userID }
    public var server: URL
    public var serverID: String
    public var userID: String
    public var name: String
    public init(server: URL, serverID: String, userID: String, name: String) {
        self.server = server; self.serverID = serverID; self.userID = userID; self.name = name
    }
}
public struct UserData: Codable, Sendable {
    public var PlaybackPositionTicks: Int64?
    public var Played: Bool?
    public var IsFavorite: Bool?
    public var LastPlayedDate: String?
}
public struct Person: Codable, Sendable {
    public var Name: String
    public var `Type`: String?
    public var Role: String?
}
public struct MediaStream: Codable, Sendable {
    public var `Type`: String
    public var Codec: String?
    public var Index: Int?
    public var Width: Int?
    public var Height: Int?
    public var VideoRangeType: String?
    public var Profile: String?
    public var IsDefault: Bool?
    public var IsExternal: Bool?
    public var Language: String?
    public init(type: String, codec: String?, width: Int? = nil, range: String? = nil) {
        self.`Type` = type; Codec = codec; Width = width; VideoRangeType = range
    }
}
public struct MediaSource: Codable, Sendable {
    public var Id: String
    public var Container: String?
    public var Size: Int64?
    public var Bitrate: Int?
    public var MediaStreams: [MediaStream]?
    public var SupportsDirectPlay: Bool?
    public var IsRemote: Bool?
    public var RequiresOpening: Bool?
    public var VideoType: String?
    public init(id: String, container: String?, streams: [MediaStream]) {
        Id = id; Container = container; MediaStreams = streams
        VideoType = "VideoFile"; IsRemote = false; RequiresOpening = false
    }
}
public struct MediaItem: Codable, Identifiable, Sendable {
    public var id: String { Id }
    public var Id: String
    public var Name: String
    public var `Type`: String?
    public var Overview: String?
    public var ProductionYear: Int?
    public var CommunityRating: Double?
    public var RunTimeTicks: Int64?
    public var SeriesId: String?
    public var SeriesName: String?
    public var ParentIndexNumber: Int?
    public var IndexNumber: Int?
    public var ImageTags: [String: String]?
    public var UserData: UserData?
    public var MediaSources: [MediaSource]?
    public var People: [Person]?
    public var Genres: [String]?
    public var CollectionType: String?
    public init(id: String, name: String) { Id = id; Name = name }
    public var position: Double { Double(UserData?.PlaybackPositionTicks ?? 0) / 10_000_000 }
}
public struct ItemPage: Codable, Sendable {
    public var Items: [MediaItem]
    public var TotalRecordCount: Int?
}
public struct PlaybackInfo: Codable, Sendable {
    public var MediaSources: [MediaSource]
    public var PlaySessionId: String?
    public var ErrorCode: String?
}

public enum CatalogRoute: Sendable {
    case resume, nextUp, recent, movies, series, search(String), children(String), episodes(String), views
}
public struct CatalogFilter: Sendable {
    public var genre = ""
    public var year = ""
    public var library = ""
    public var unplayed = false
    public var sort = "SortName"
    public init() {}
}
