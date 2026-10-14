import SwiftUI
import UIKit

@MainActor final class AlternativePlayer: ObservableObject {
    let bridge = MFVLCBridge()
    @Published var seconds: Double = 0
    @Published var duration: Double = 0
    @Published var paused = true
    @Published var audio: [LocalTrack] = []
    @Published var subtitles: [LocalTrack] = []
    var onEvent: ((String) -> Void)?
    init() {
        bridge.onEvent = { [weak self] event, seconds, duration, paused in
            guard let self else { return }
            self.seconds = seconds; self.duration = duration; self.paused = paused
            self.audio = self.tracks(self.bridge.audioTracks)
            self.subtitles = self.tracks(self.bridge.subtitleTracks)
            self.onEvent?(event)
        }
    }
    private func tracks(_ rows: [Any]) -> [LocalTrack] {
        rows.compactMap { value in
            guard let row = value as? [AnyHashable: Any] else { return nil }
            guard let id = row["index"] as? Int, let name = row["name"] as? String else { return nil }
            return .init(id: id, name: name, selected: row["selected"] as? Bool ?? false)
        }
    }
    func open(url: URL, resume: Double) { bridge.open(url: url, resume: resume) }
    func seek(_ seconds: Double) { bridge.seek(seconds: seconds) }
    func stop() { onEvent = nil; bridge.stop() }
}
struct LocalTrack: Identifiable { let id: Int; let name: String; let selected: Bool }
private struct AlternativeSurface: UIViewRepresentable {
    let player: AlternativePlayer
    func makeUIView(context: Context) -> UIView { player.bridge.surface }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
struct AlternativePlayerView: View {
    @ObservedObject var player: AlternativePlayer
    var body: some View {
        VStack {
            AlternativeSurface(player: player).frame(maxWidth: .infinity, maxHeight: .infinity).background(.black)
            #if os(iOS)
            Slider(value: Binding(get: { player.seconds }, set: { player.seek($0) }), in: 0...max(1, player.duration)).disabled(!player.bridge.seekable)
                .accessibilityLabel("player.seek")
            #endif
            Text("\(Int(player.seconds)) / \(Int(player.duration)) s").font(.caption.monospacedDigit())
            HStack {
                Button { player.seek(player.seconds - 10) } label: { Image(systemName: "gobackward.10") }
                Button { player.paused ? player.bridge.play() : player.bridge.pause() } label: { Image(systemName: player.paused ? "play.fill" : "pause.fill") }
                Button { player.seek(player.seconds + 10) } label: { Image(systemName: "goforward.10") }
            }
            if !player.audio.isEmpty {
                Picker("player.audio", selection: Binding(get: { player.audio.first(where: \.selected)?.id ?? -1 }, set: { player.bridge.selectAudio(index: $0) })) {
                    ForEach(player.audio) { Text($0.name).tag($0.id) }
                }
            }
            if !player.subtitles.isEmpty {
                Picker("player.subtitles", selection: Binding(get: { player.subtitles.first(where: \.selected)?.id ?? -1 }, set: { player.bridge.selectSubtitle(index: $0) })) {
                    Text("player.subtitlesOff").tag(-1)
                    ForEach(player.subtitles) { Text($0.name).tag($0.id) }
                }
            }
        }.padding()
        #if os(tvOS)
        .onPlayPauseCommand { player.paused ? player.bridge.play() : player.bridge.pause() }
        #endif
    }
}
