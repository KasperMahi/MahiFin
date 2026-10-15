import Foundation

public enum CastSafety {
    public static func validReceiverID(_ value: String) -> Bool {
        value.count == 8 && value.allSatisfy { "0123456789abcdefABCDEF".contains($0) }
    }
    public static func permitsCredentialEnvelope(receiverLogRedacted: Bool, noImplicitVideoConversion: Bool) -> Bool {
        receiverLogRedacted && noImplicitVideoConversion
    }
}
