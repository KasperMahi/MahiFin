import XCTest
@testable import MahiFinCore

final class DownloadIntegrityTests: XCTestCase {
    func testShortHTTPResponseCannotRedefineOriginalSize() {
        XCTAssertFalse(DownloadIntegrity.isComplete(bytes: 500, originalSize: 1000, responseSize: 500))
        XCTAssertFalse(DownloadIntegrity.isComplete(bytes: 0, originalSize: 1000, responseSize: 0))
        XCTAssertFalse(DownloadIntegrity.isComplete(bytes: 1000, originalSize: nil, responseSize: 1000))
        XCTAssertTrue(DownloadIntegrity.isComplete(bytes: 1000, originalSize: 1000, responseSize: -1))
        XCTAssertTrue(DownloadIntegrity.isComplete(bytes: 1000, originalSize: 1000, responseSize: 1000))
    }
    func testCompletedOfflineActivityRestartsAtZero() {
        var event = HistoryEvent(account: "fixture", item: "i", ticks: 15000000000, completed: true, occurred: Date(), sequence: 1, device: "fixture")
        XCTAssertEqual(ResumePosition.local(item: .init(id: "i", name: "Invented"), pending: event), 0)
        event.completed = false; event.ticks = 7200000000
        XCTAssertEqual(ResumePosition.local(item: .init(id: "i", name: "Invented"), pending: event), 720)
    }
}
