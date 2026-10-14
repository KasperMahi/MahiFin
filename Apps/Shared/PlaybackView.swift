import SwiftUI
import AVKit
import MahiFinCore

struct NativePlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController(); controller.player = player
        controller.showsPlaybackControls = true
        #if os(iOS)
        controller.allowsPictureInPicturePlayback = true
        #endif
        return controller
    }
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) { controller.player = player }
}
@MainActor final class PlaybackSession: ObservableObject {
    @Published var player: AVPlayer?
    @Published var failure: String?
    @Published var loading = true
    @Published var next: MediaItem?
    @Published var countdown = NextCountdown()
    @Published var completed = false
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var failureObserver: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?
    private var lastReport: Double = -15
    private var source: MediaSource?
    private var sessionID = UUID().uuidString
    private var item: MediaItem?
    private var account: Account?
    private var api: JellyfinClient?
    private weak var model: AppModel?
    private var stopped = false
    private var reporting = false
    private var online = false
    private var countdownTask: Task<Void, Never>?
    private var pipeline: Task<Void, Never>?
    private var generation = UUID()

    func open(_ item: MediaItem, model: AppModel, localURL: URL? = nil, localSource: MediaSource? = nil) async {
        await stop()
        generation = UUID()
        let currentGeneration = generation
        stopped = false; completed = false; next = nil; countdown = .init(); loading = true; failure = nil
        self.item = item; self.model = model; account = model.active; lastReport = -15
        guard let account else { failure = NSLocalizedString("error.auth", comment: ""); loading = false; return }
        do {
            let url: URL
            var resume = item.position
            if let pending = await model.history.pending(account: account.id).first(where: { $0.item == item.Id }) {
                resume = Double(pending.ticks) / 10_000_000
            }
            if let localURL, let localSource {
                online = false; api = nil; source = localSource; url = localURL
            } else {
                online = true
                let client = try model.client(for: account); api = client
                let fresh = try await client.item(user: account.userID, id: item.Id)
                resume = fresh.position
                let info = try await client.playbackInfo(user: account.userID, item: item.Id)
                guard info.ErrorCode == nil, let selected = info.MediaSources.first else { throw ClientError.unavailable }
                source = selected; sessionID = info.PlaySessionId ?? UUID().uuidString
                let decision = PlaybackPolicy.decide(selected, device: .init())
                model.diagnostic = DiagnosticReport(source: selected, decision: decision)
                guard decision.route == .direct else { throw ClientError.unavailable }
                url = try client.directURL(item: item.Id, source: selected)
            }
            try Task.checkCancellation()
            guard generation == currentGeneration, !stopped else { return }
            let asset = AVURLAsset(url: url)
            let playable = try await asset.load(.isPlayable)
            guard playable else { throw ClientError.unavailable }
            try Task.checkCancellation()
            guard generation == currentGeneration, !stopped else { return }
            let playerItem = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: playerItem)
            player.allowsExternalPlayback = true
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
            self.player = player
            if resume > 0 { await player.seek(to: CMTime(seconds: resume, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) }
            if online, let api {
                try await api.report(SessionEvent(item: item.Id, source: source?.Id, session: sessionID, seconds: resume, paused: false), endpoint: "Playing")
            }
            guard generation == currentGeneration, !stopped else { return }
            failureObserver = playerItem.observe(\.status, options: [.new]) { [weak self] value, _ in
                if value.status == .failed { Task { @MainActor in self?.failed() } }
            }
            rateObserver = player.observe(\.rate, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in await self?.checkpoint(force: true) }
            }
            timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { [weak self] _ in
                Task { @MainActor in await self?.checkpoint(force: false) }
            }
            endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { [weak self] _ in
                Task { @MainActor in await self?.ended() }
            }
            loading = false; player.play()
        } catch {
            loading = false; failed()
        }
    }
    func checkpoint(force: Bool) async {
        guard !stopped, !reporting, let player, let item, let account, let model else { return }
        let seconds = player.currentTime().seconds
        guard seconds.isFinite else { return }
        guard force || abs(seconds - lastReport) >= 15 else { return }
        reporting = true; defer { reporting = false }
        lastReport = seconds
        await model.record(account: account, item: item, seconds: seconds, completed: completed)
        if online, let api {
            try? await api.report(SessionEvent(item: item.Id, source: source?.Id, session: sessionID, seconds: seconds, paused: player.rate == 0), endpoint: "Playing/Progress")
        }
    }
    func stop() async {
        guard !stopped else { return }
        stopped = true; generation = UUID(); countdownTask?.cancel()
        player?.pause()
        if let timeObserver { player?.removeTimeObserver(timeObserver); self.timeObserver = nil }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver); self.endObserver = nil }
        failureObserver = nil; rateObserver = nil
        if let player, let item, let account, let model {
            let seconds = player.currentTime().seconds
            await model.record(account: account, item: item, seconds: seconds, completed: completed)
            if online, let api {
                try? await api.report(SessionEvent(item: item.Id, source: source?.Id, session: sessionID, seconds: seconds, paused: true), endpoint: "Playing/Stopped")
            }
        }
        player = nil
    }
    func cancelNext() { countdown.cancel(); countdownTask?.cancel(); next = nil }
    private func failed() {
        player?.pause(); loading = false
        failure = NSLocalizedString("player.unsupported", comment: "")
        model?.diagnostic = DiagnosticReport(source: source, decision: source.map { PlaybackPolicy.decide($0, device: .init()) }, issue: "player")
    }
    private func ended() async {
        guard !completed, !stopped, let item, let account, let api, let model else {
            if !online { completed = true; await checkpoint(force: true) }
            return
        }
        completed = true
        await stop()
        guard let series = item.SeriesId else { return }
        do {
            var episodes: [MediaItem] = []; var offset = 0
            while true {
                let page = try await api.items(user: account.userID, route: .episodes(series), start: offset)
                episodes += page.Items; offset += page.Items.count
                if page.Items.isEmpty || offset >= (page.TotalRecordCount ?? offset) { break }
            }
            let ordered = episodes.sorted { ($0.ParentIndexNumber ?? 0, $0.IndexNumber ?? 0) < ($1.ParentIndexNumber ?? 0, $1.IndexNumber ?? 0) }
            guard let index = ordered.firstIndex(where: { $0.Id == item.Id }), index + 1 < ordered.count else { return }
            next = ordered[index + 1]; countdown = .init()
            countdownTask = Task { @MainActor [weak self] in
                for _ in 0..<5 {
                    do { try await Task.sleep(for: .seconds(1)) } catch { return }
                    guard let self, !self.countdown.cancelled else { return }
                    if self.countdown.tick(), let next = self.next { await self.open(next, model: model); return }
                }
            }
        } catch { model.show(error) }
    }
}
struct PlaybackView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var session = PlaybackSession()
    let item: MediaItem
    var localURL: URL? = nil
    var localSource: MediaSource? = nil
    var body: some View {
        VStack(spacing: 20) {
            if session.loading { ProgressView("player.loading") }
            if let failure = session.failure { Text(failure).padding(); Button("retry") { Task { await session.open(item, model: model, localURL: localURL, localSource: localSource) } } }
            if let player = session.player { NativePlayer(player: player).ignoresSafeArea(edges: .bottom) }
            if let next = session.next {
                Text(next.Name)
                Text(String(session.countdown.remaining)).font(.largeTitle.monospacedDigit())
                Button("player.cancelNext") { session.cancelNext() }
            }
            #if os(iOS)
            if session.player != nil { AirPlayPicker().frame(width: 44, height: 44).accessibilityLabel("player.airplay") }
            #endif
        }.navigationTitle(item.Name)
        .task { await session.open(item, model: model, localURL: localURL, localSource: localSource) }
        .onDisappear { session.cancelNext(); Task { await session.stop() } }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { Task { await session.checkpoint(force: true) } }
        }
    }
}
