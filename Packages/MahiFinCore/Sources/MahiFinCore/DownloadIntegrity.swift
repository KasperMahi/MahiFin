import Foundation

public enum DownloadIntegrity {
    public static func isComplete(bytes: Int64, originalSize: Int64?, responseSize: Int64) -> Bool {
        guard bytes > 0, let originalSize, originalSize > 0, bytes == originalSize else { return false }
        return responseSize <= 0 || responseSize == bytes
    }
}
public enum ResumePosition {
    public static func local(item: MediaItem, pending: HistoryEvent?) -> Double {
        guard let pending else { return item.position }
        return pending.completed ? 0 : Double(pending.ticks) / 10_000_000
    }
}
