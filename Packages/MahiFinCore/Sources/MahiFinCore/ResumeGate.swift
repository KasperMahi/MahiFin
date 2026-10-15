import Foundation

/// Decoder preroll is not new viewing activity. Preserve the requested resume
/// until the engine reports its settled position, including an early stop/error.
public struct ResumeGate: Sendable {
    private var target: Double?
    public init(position: Double) { target = position.isFinite && position > 0 ? position : nil }
    public mutating func observe(seconds: Double, duration: Double) -> Bool {
        guard var target else { return true }
        if duration.isFinite, duration > 0 { target = min(target, max(0, duration - 1)); self.target = target }
        guard seconds.isFinite, abs(seconds - target) <= 2 else { return false }
        self.target = nil; return true
    }
    public func stopPosition(seconds: Double) -> Double { target ?? (seconds.isFinite ? max(0, seconds) : 0) }
}
