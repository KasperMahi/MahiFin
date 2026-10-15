import Foundation

/// Source-of-truth lifecycle for exactly one local engine, independent of native/VLC callbacks.
public struct PlaybackLedger: Sendable {
    public private(set) var generation = UUID()
    public private(set) var active = false
    public private(set) var completed = false
    public private(set) var lastPosition: Double = 0
    public private(set) var stopCount = 0
    public init() {}
    @discardableResult public mutating func begin(position: Double) -> UUID {
        generation = UUID(); active = true; completed = false
        lastPosition = position.isFinite ? max(0, position) : 0
        return generation
    }
    public mutating func checkpoint(_ position: Double, generation: UUID) -> Bool {
        guard active, self.generation == generation, position.isFinite, position >= 0 else { return false }
        lastPosition = position; return true
    }
    public mutating func complete(generation: UUID) -> Bool {
        guard active, self.generation == generation, !completed else { return false }
        completed = true; return true
    }
    public mutating func stop(generation: UUID) -> Bool {
        guard active, self.generation == generation else { return false }
        active = false; stopCount += 1; return true
    }
}
