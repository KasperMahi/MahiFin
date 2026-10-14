import Foundation

public enum DownloadIntegrity {
    public static func isComplete(bytes: Int64, originalSize: Int64?, responseSize: Int64, status: Int = 200, contentRange: String? = nil) -> Bool {
        guard bytes > 0, let originalSize, originalSize > 0, bytes == originalSize else { return false }
        if status == 206 {
            guard let contentRange, contentRange.hasPrefix("bytes ") else { return false }
            let parts = contentRange.dropFirst(6).split(separator: "/")
            guard parts.count == 2, Int64(parts[1]) == originalSize else { return false }
            let range = parts[0].split(separator: "-")
            guard range.count == 2, let start = Int64(range[0]), let end = Int64(range[1]), start >= 0, end >= start, end == originalSize - 1 else { return false }
            return responseSize <= 0 || responseSize == end - start + 1
        }
        guard status == 200 else { return false }
        return responseSize <= 0 || responseSize == bytes
    }
}
public enum ResumePosition {
    public static func local(item: MediaItem, pending: HistoryEvent?) -> Double {
        guard let pending else { return item.position }
        return pending.completed ? 0 : Double(pending.ticks) / 10_000_000
    }
}
