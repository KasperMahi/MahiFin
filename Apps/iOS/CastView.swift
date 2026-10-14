import SwiftUI
import MahiFinCore
import MahiFinCastSDK

@MainActor final class CastModel: ObservableObject, CastController {
    let bridge = MFCastBridge()
    @Published var configured = false
    @Published var state = "disconnected"
    @Published var seconds: Double = 0
    @Published var paused = true
    @Published var hasMedia = false
    @Published var error: String?
    init() {
        bridge.onStatus = { [weak self] state, seconds, paused, hasMedia in
            self?.state = state; self?.seconds = seconds; self?.paused = paused; self?.hasMedia = hasMedia
        }
    }
    func prepare(account: Account, client: JellyfinClient) async {
        configured = false; error = nil
        do {
            let user = try await client.user(id: account.userID)
            guard let rawReceiver = user.Configuration?.CastReceiverId else { throw ClientError.unavailable }
            let receiver = rawReceiver.uppercased()
            let services = Bundle.main.object(forInfoDictionaryKey: "NSBonjourServices") as? [String] ?? []
            guard CastSafety.validReceiverID(receiver), services.contains("_\(receiver)._googlecast._tcp"),
                  bridge.configure(receiver: receiver) else { throw ClientError.unavailable }
            configured = true
        } catch { self.error = NSLocalizedString("cast.setupFailed", comment: "") }
    }
    func status() async -> CastStatus { state == "receiver" ? (hasMedia && !paused ? .playing : .connected) : .disconnected }
    func load(_ item: MediaItem, decision: PlaybackDecision) async throws {
        // Receiver source logs the complete token-bearing custom envelope. Never transmit it from this sender.
        throw ClientError.unavailable
    }
    func pause() async throws { guard state == "receiver", hasMedia else { throw ClientError.unavailable }; bridge.pause() }
    func seek(seconds: Double) async throws { guard state == "receiver", hasMedia else { throw ClientError.unavailable }; bridge.seek(seconds: seconds) }
    func disconnect() { bridge.disconnect(); state = "disconnected"; hasMedia = false; configured = false }
}
private struct CastButton: UIViewRepresentable {
    let bridge: MFCastBridge
    func makeUIView(context: Context) -> UIView { bridge.makeButton() }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
struct CastView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var cast: CastModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("cast.privacyBlock")
            Button("cast.discover") {
                Task {
                    guard let account = model.active, let client = try? model.client(for: account) else { return }
                    await cast.prepare(account: account, client: client)
                }
            }
            if cast.configured { CastButton(bridge: cast.bridge).frame(width: 44, height: 44).accessibilityLabel("cast.select") }
            Text(LocalizedStringKey("cast." + cast.state))
            if let error = cast.error { Text(error) }
            if cast.state == "receiver" && cast.hasMedia {
                Text("cast.existingMedia")
                HStack {
                    Button(cast.paused ? "player.play" : "player.pause") { cast.paused ? cast.bridge.play() : cast.bridge.pause() }
                    Button("cast.seekBack") { cast.bridge.seek(seconds: max(0, cast.seconds - 10)) }
                    Button("cast.seekForward") { cast.bridge.seek(seconds: cast.seconds + 10) }
                }
            }
            if cast.state == "receiver" { Button("cast.disconnect") { cast.disconnect() } }
        }
    }
}
