#if DEBUG
import SwiftUI

/// Explicit UI-test harness only. Normal app routes always use the real account/client.
struct PlaybackFixtureView: View {
    @StateObject private var player = AlternativePlayer()
    @State private var status = "opening"
    var body: some View {
        VStack {
            Text("Synthetic MKV integration test")
            Text(status).accessibilityIdentifier("fixture.status")
            AlternativePlayerView(player: player)
            Button("Seek to six seconds") { player.seek(6) }.accessibilityIdentifier("fixture.seek")
        }.onAppear {
            player.onEvent = { event in if event != "time" { status = event } }
            guard let url = Bundle.main.url(forResource: "synthetic", withExtension: "mkv", subdirectory: "PlaybackFixtures") else { status = "missing-fixture"; return }
            player.open(url: url, resume: 0)
        }.onDisappear { player.stop() }
    }
}
#endif
