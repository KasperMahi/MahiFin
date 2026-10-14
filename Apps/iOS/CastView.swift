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
    func seek(seconds: Double) async throws { throw ClientError.unavailable /* Requires source-unknown receiver conversion confirmation in CastView. */ }
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
    @State private var pendingScope: String?
    @State private var pendingSeek: Double?
    @State private var showControlConsent = false
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
                    Button(LocalizedStringKey(cast.paused ? "player.play" : "player.pause")) {
                        if cast.paused { pendingSeek = nil; pendingScope = cast.bridge.mediaIdentity }
                        else { cast.bridge.pause() }
                    }
                    Button("cast.seekBack") { pendingSeek = max(0, cast.seconds - 10); pendingScope = cast.bridge.mediaIdentity }
                    Button("cast.seekForward") { pendingSeek = cast.seconds + 10; pendingScope = cast.bridge.mediaIdentity }
                }
            }
            if cast.state == "receiver" { Button("cast.disconnect") { cast.disconnect() } }
        }.alert("cast.controlConsentTitle", isPresented: $showControlConsent, presenting: pendingScope) { scope in
            Button("cancel", role: .cancel) { pendingScope = nil }
            Button("cast.controlConsentAccept") {
                guard pendingScope == scope, !scope.isEmpty, scope == cast.bridge.mediaIdentity else { pendingScope = nil; return }
                if let pendingSeek { cast.bridge.seek(seconds: pendingSeek) } else { cast.bridge.play() }
                pendingScope = nil
            }
        } message: { _ in Text("cast.controlConsentBody") }
        .onChange(of: pendingScope) { _, scope in showControlConsent = scope != nil }
    }
}
