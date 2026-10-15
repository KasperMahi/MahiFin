import XCTest
@testable import MahiFinCore

final class CastSafetyTests: XCTestCase {
    func testReceiverIDCannotBeURLOrUntrustedNamespace() {
        XCTAssertTrue(CastSafety.validReceiverID("0123ABCD"))
        XCTAssertFalse(CastSafety.validReceiverID("https://example.invalid?api_key=fixture"))
        XCTAssertFalse(CastSafety.validReceiverID("not-an-id"))
    }
    func testAuthenticationIsBlockedIfReceiverLeaksOrCanSilentlyConvert() {
        XCTAssertFalse(CastSafety.permitsCredentialEnvelope(receiverLogRedacted: false, noImplicitVideoConversion: true))
        XCTAssertFalse(CastSafety.permitsCredentialEnvelope(receiverLogRedacted: true, noImplicitVideoConversion: false))
    }
}
