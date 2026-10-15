#if DEBUG
import SwiftUI
import MahiFinCore

/// Explicit UI-test harness only. Normal app routes always use the real account/client.
struct PlaybackFixtureView: View {
    @StateObject private var player = AlternativePlayer()
    @State private var status = "ready"
    @FocusState private var startFocused: Bool
    var body: some View {
        VStack {
            Text("Synthetic MKV integration test")
            Button("Start synthetic MKV") {
                guard let url = Bundle.main.url(forResource: "synthetic", withExtension: "mkv", subdirectory: "PlaybackFixtures") else { status = "missing-fixture"; return }
                status = "opening"; player.open(url: url, resume: 0)
            }.accessibilityIdentifier("fixture.start").focused($startFocused)
            Text(status).accessibilityIdentifier("fixture.status")
            Text("\(player.audio.count) audio / \(player.subtitles.count) subtitles").accessibilityIdentifier("fixture.tracks")
            Text(String(player.subtitles.first(where: \.selected)?.id ?? -1)).accessibilityIdentifier("fixture.subtitle")
            Text(String(Int(player.seconds))).accessibilityIdentifier("fixture.position")
            AlternativePlayerView(player: player)
            HStack {
                Button("Hide subtitle") { player.bridge.selectSubtitle(index: -1) }.accessibilityIdentifier("fixture.hideSubtitle")
                Button("Select embedded subtitle") { player.bridge.selectSubtitle(index: 0) }.accessibilityIdentifier("fixture.selectSubtitle")
            }
            Button("Seek near end") { player.seek(max(6, player.duration - 6)) }.accessibilityIdentifier("fixture.seek")
        }.onAppear {
            player.onEvent = { event in if event != "time" { status = event } }
            startFocused = true
        }.onDisappear { player.stop() }
    }
}

/// Exercises the production dialog and actual URL consent boundary, without network or stored credentials.
struct ConversionConsentFixtureView: View {
    @State private var request: PendingVideoConsent?
    @State private var constructed = 0
    @State private var result = "idle"
    private let account = Account(server: URL(string: "https://example.invalid")!, serverID: "fixture", userID: "fixture", name: "Invented")
    private let source = MediaSource(id: "fixture", container: "mkv", streams: [.init(type: "Video", codec: "unsupported-fixture", width: 1920)])
    var body: some View {
        VStack(spacing: 24) {
            Text("Encoding URLs: \(constructed)").accessibilityIdentifier("consent.count")
            Text(result).accessibilityIdentifier("consent.result")
            Button("Request conversion") {
                if PlaybackPolicy.decide(source, device: .init()).route == .needsVideoConsent {
                    request = .init(account: account.id, item: "fixture", source: source.Id)
                }
            }.accessibilityIdentifier("consent.request")
        }.videoConversionConsent(request: $request, accept: { presented in
            guard request?.id == presented.id else { return }
            do {
                let client = try JellyfinClient(server: account.server, token: "invented-ui-fixture", deviceID: "fixture")
                let grant = VideoConsent.accept(account: presented.account, item: presented.item, source: presented.source)
                let url = try client.conversionURL(account: account, item: presented.item, source: source, session: "fixture", mode: .video, consent: grant)
                if URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.contains(where: { $0.name == "VideoCodec" && $0.value == "h264" }) == true {
                    constructed += 1; result = "accepted"
                }
            } catch { result = "rejected" }
        }, decline: { result = "declined" })
    }
}
#endif
