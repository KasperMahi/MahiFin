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
    @Published var alternative: AlternativePlayer?
    @Published var consentRequest: PendingVideoConsent?
    @Published var currentTitle = ""
    @Published var failure: String?
    @Published var loading = true
    @Published var next: MediaItem?
    @Published var countdown = NextCountdown()
    @Published var completed = false
    @Published var activeSegment: MediaSegment?
    private var segments: [MediaSegment] = []
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var playbackFailureObserver: NSObjectProtocol?
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
    private var networkTask: Task<Void, Never>?
    private var generation = UUID()
    private var openOperation = UUID()
    private var conversionActive = false
    private var playMethod = "DirectPlay"
    private var ledger = PlaybackLedger()
    private var selectedDecision: PlaybackDecision?

    func open(_ item: MediaItem, model: AppModel, localURL: URL? = nil, localSource: MediaSource? = nil, consent: VideoConsent? = nil) async {
        let operation = UUID(); openOperation = operation
        await stop(cancelOpening: false)
        guard openOperation == operation, !Task.isCancelled else { return }
        generation = ledger.begin(position: 0)
        let currentGeneration = generation
        stopped = false; completed = false; next = nil; countdown = .init(); loading = true; failure = nil
        activeSegment = nil; segments = []
        currentTitle = item.Name; selectedDecision = nil
        consentRequest = nil; conversionActive = false; playMethod = "DirectPlay"
        self.item = item; self.model = model; account = model.active; lastReport = -15
        guard let account else { failure = NSLocalizedString("error.auth", comment: ""); loading = false; return }
        do {
            let url: URL
            var decision: PlaybackDecision
            // An offline original cannot use a server fallback. Select an available local
            // engine even when the user's online preference would otherwise request remux.
            let capabilities = NativeCapabilities.probe(preference: localURL == nil ? model.enginePreference : .automatic)
            var resume = item.position
            let pending = await model.history.pending(account: account.id).first(where: { $0.item == item.Id })
            let latest = await model.history.latest(account: account.id, item: item.Id)
            guard generation == currentGeneration, !stopped else { return }
            resume = ResumePosition.local(item: item, pending: latest)
            if let localURL, let localSource {
                online = false; api = nil; source = localSource; url = localURL
                decision = PlaybackPolicy.decide(localSource, device: capabilities)
            } else {
                online = true
                let client = try model.client(for: account); api = client
                let fresh = try await client.item(user: account.userID, id: item.Id)
                guard generation == currentGeneration, !stopped else { return }
                resume = fresh.position
                if let pending {
                    let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    let serverDate = fresh.UserData?.LastPlayedDate.flatMap { formatter.date(from: $0) ?? ISO8601DateFormatter().date(from: $0) }
                    if HistoryConflict.resolve(pending, serverDate: serverDate, now: Date()) == .upload {
                        resume = pending.completed ? 0 : Double(pending.ticks) / 10_000_000
                    }
                }
                let info = try await client.playbackInfo(user: account.userID, item: item.Id)
                guard generation == currentGeneration, !stopped else { return }
                guard info.ErrorCode == nil, let selected = info.MediaSources.first else { throw ClientError.unavailable }
                source = selected; sessionID = info.PlaySessionId ?? UUID().uuidString
                decision = PlaybackPolicy.decide(selected, device: capabilities)
                model.diagnostic = DiagnosticReport(source: selected, decision: decision)
                if decision.route == .needsVideoConsent && consent == nil {
                    consentRequest = .init(account: account.id, item: item.Id, source: selected.Id)
                    loading = false; return
                }
                if decision.route == .remux || decision.route == .audioOnly || decision.route == .needsVideoConsent {
                    let mode: ConversionMode = decision.route == .remux ? .remux : (decision.route == .audioOnly ? .audioOnly : .video)
                    url = try client.conversionURL(account: account, item: item.Id, source: selected, session: sessionID, mode: mode, consent: consent)
                    conversionActive = true; playMethod = mode == .remux ? "DirectStream" : "Transcode"
                    // Server produces native HLS. Consent never changes the original policy grant globally.
                    decision = .init(route: .direct, reason: "server." + mode.rawValue)
                } else {
                    guard decision.canStart else { throw ClientError.unavailable }
                    url = try client.directURL(item: item.Id, source: selected)
                }
            }
            try Task.checkCancellation()
            guard generation == currentGeneration, !stopped else { return }
            selectedDecision = decision
            model.diagnostic = DiagnosticReport(source: source, decision: selectedDecision)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
            if decision.route == .alternative {
                let local = AlternativePlayer()
                alternative = local
                local.onEvent = { [weak self] event in
                    Task { @MainActor in
                        guard let self, self.generation == currentGeneration else { return }
                        if event == "error" { self.failed() }
                        else if event == "ended" { await self.ended() }
                        else {
                            self.loading = false
                            self.activeSegment = self.segments.first { $0.active(item: item.Id, seconds: local.seconds) }
                            await self.checkpoint(force: event != "time")
                        }
                    }
                }
                if online, let api {
                    let fetchedSegments = (try? await api.segments(item: item.Id)) ?? []
                    guard generation == currentGeneration, !stopped else { return }
                    segments = fetchedSegments
                    await enqueueReport(client: api, event: eventFor(item: item, seconds: resume, paused: false), endpoint: "Playing").value
                }
                guard generation == currentGeneration, !stopped else { return }
                local.open(url: url, resume: resume)
                return
            }
            guard decision.route == .direct else { throw ClientError.unavailable }
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
            if online, let api {
                let fetchedSegments = (try? await api.segments(item: item.Id)) ?? []
                guard generation == currentGeneration, !stopped else { return }
                segments = fetchedSegments
                if let preferences = try? await api.user(id: account.userID).Configuration {
                    await apply(preferences, asset: asset, item: playerItem)
                }
            }
            try Task.checkCancellation()
            guard generation == currentGeneration, !stopped else { return }
            if resume > 0 { await player.seek(to: CMTime(seconds: resume, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) }
            guard generation == currentGeneration, !stopped else { return }
            if online, let api {
                await enqueueReport(client: api, event: eventFor(item: item, seconds: resume, paused: false), endpoint: "Playing").value
            }
            guard generation == currentGeneration, !stopped else { return }
            failureObserver = playerItem.observe(\.status, options: [.new]) { [weak self] value, _ in
                if value.status == .failed { Task { @MainActor in
                    guard let self, self.generation == currentGeneration else { return }; self.failed()
                } }
            }
            rateObserver = player.observe(\.rate, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in
                    guard let self, self.generation == currentGeneration else { return }; await self.checkpoint(force: true)
                }
            }
            timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.generation == currentGeneration else { return }
                    self.activeSegment = self.segments.first { $0.active(item: self.item?.Id ?? "", seconds: self.player?.currentTime().seconds ?? 0) }
                    await self.checkpoint(force: false)
                }
            }
            endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.generation == currentGeneration else { return }; await self.ended()
                }
            }
            playbackFailureObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: playerItem, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.generation == currentGeneration else { return }; self.failed()
                }
            }
            loading = false; player.play()
        } catch {
            guard generation == currentGeneration, !stopped else { return }
            let issue = (error as? ClientError) == .unauthorized ? "auth" : ((error as? ClientError) == .unavailable ? "unsupported" : "network")
            loading = false; failed(issue: issue)
        }
    }
    func checkpoint(force: Bool) async {
        guard !stopped, !reporting, player != nil || alternative != nil, let item, let account, let model else { return }
        let seconds = alternative?.seconds ?? player?.currentTime().seconds ?? 0
        let paused = alternative?.paused ?? (player?.rate == 0)
        guard seconds.isFinite else { return }
        guard ledger.checkpoint(seconds, generation: generation) else { return }
        guard force || abs(seconds - lastReport) >= 15 else { return }
        reporting = true; defer { reporting = false }
        lastReport = seconds
        // Capture immutable session identity before an await permits a stop/profile switch.
        let client = online ? api : nil
        var event = SessionEvent(item: item.Id, source: source?.Id, session: sessionID, seconds: seconds, paused: paused)
        event.PlayMethod = playMethod
        let task = client.map { enqueueReport(client: $0, event: event, endpoint: "Playing/Progress") }
        await model.record(account: account, item: item, seconds: seconds, completed: completed)
        await task?.value
    }
    @discardableResult func stop(cancelOpening: Bool = true) async -> UUID {
        _ = ledger.stop(generation: generation)
        if cancelOpening { openOperation = UUID() }
        let stoppedGeneration = UUID(); generation = stoppedGeneration
        guard !stopped else { return stoppedGeneration }
        stopped = true; countdownTask?.cancel()
        player?.pause()
        if let timeObserver { player?.removeTimeObserver(timeObserver); self.timeObserver = nil }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver); self.endObserver = nil }
        if let playbackFailureObserver { NotificationCenter.default.removeObserver(playbackFailureObserver); self.playbackFailureObserver = nil }
        failureObserver = nil; rateObserver = nil
        let stoppedPlayer = player
        let conversionClient = conversionActive ? api : nil
        let conversionSession = sessionID
        let stoppedAlternative = alternative
        let lastSeconds = stoppedAlternative?.seconds ?? stoppedPlayer?.currentTime().seconds ?? 0
        stoppedAlternative?.stop(); alternative = nil
        player = nil // Detach before await so an older stop cannot clear a replacement player.
        if stoppedPlayer != nil || stoppedAlternative != nil, let item, let account, let model {
            let seconds = lastSeconds
            let client = online ? api : nil
            var event = SessionEvent(item: item.Id, source: source?.Id, session: sessionID, seconds: seconds, paused: true)
            event.PlayMethod = playMethod
            let task = client.map { enqueueReport(client: $0, event: event, endpoint: "Playing/Stopped") }
            await model.record(account: account, item: item, seconds: seconds, completed: completed)
            await task?.value
        }
        if let conversionClient { try? await conversionClient.stopConversion(session: conversionSession) }
        return stoppedGeneration
    }
    private func eventFor(item: MediaItem, seconds: Double, paused: Bool) -> SessionEvent {
        var value = SessionEvent(item: item.Id, source: source?.Id, session: sessionID, seconds: seconds, paused: paused)
        value.PlayMethod = playMethod
        return value
    }
    private func enqueueReport(client: JellyfinClient, event: SessionEvent, endpoint: String) -> Task<Void, Never> {
        let preceding = networkTask
        let task = Task {
            await preceding?.value
            try? await client.report(event, endpoint: endpoint)
        }
        networkTask = task
        return task
    }
    func cancelNext() { countdown.cancel(); countdownTask?.cancel(); next = nil }
    func approveVideo(_ request: PendingVideoConsent) {
        guard consentRequest?.id == request.id, let item, let model, model.active?.id == request.account,
              item.Id == request.item, source?.Id == request.source else { return }
        let consent = VideoConsent.accept(account: request.account, item: request.item, source: request.source)
        consentRequest = nil
        Task { await open(item, model: model, consent: consent) }
    }
    func declineVideo() { consentRequest = nil; loading = false; failure = NSLocalizedString("player.conversionDeclined", comment: "") }
    func skipSegment() {
        guard let segment = activeSegment else { return }
        if let alternative { alternative.seek(Double(segment.EndTicks) / 10_000_000); return }
        player?.seek(to: CMTime(seconds: Double(segment.EndTicks) / 10_000_000, preferredTimescale: 600))
    }
    private func apply(_ preferences: UserPreferences, asset: AVAsset, item: AVPlayerItem) async {
        func language(_ value: String?) -> String? {
            guard let value else { return nil }
            return ["eng": "en", "dan": "da" ][value] ?? value
        }
        if preferences.PlayDefaultAudioTrack == false, let preferred = language(preferences.AudioLanguagePreference),
           let group = try? await asset.loadMediaSelectionGroup(for: .audible),
           let option = group.options.first(where: { $0.extendedLanguageTag?.hasPrefix(preferred) == true }) {
            item.select(option, in: group)
        }
        if let group = try? await asset.loadMediaSelectionGroup(for: .legible) {
            if preferences.SubtitleMode == "None" { item.select(nil, in: group) }
            else if preferences.SubtitleMode == "OnlyForced" {
                item.select(group.options.first(where: { $0.hasMediaCharacteristic(.containsOnlyForcedSubtitles) }), in: group)
            } else if let preferred = language(preferences.SubtitleLanguagePreference),
                      let option = group.options.first(where: { $0.extendedLanguageTag?.hasPrefix(preferred) == true }) {
                item.select(option, in: group)
            }
        }
        // External/image subtitles not exposed by the native asset remain unsupported; no burn-in request.
    }
    private func failed(issue: String = "player") {
        player?.pause(); loading = false
        alternative?.bridge.pause()
        let key = issue == "auth" ? "error.auth" : (issue == "network" ? "error.network" : "player.unsupported")
        failure = NSLocalizedString(key, comment: "")
        model?.diagnostic = DiagnosticReport(source: source, decision: selectedDecision, issue: issue)
    }
    private func ended() async {
        guard ledger.complete(generation: generation) else { return }
        guard !completed, !stopped, let item, let account, let api, let model else {
            if !online && !stopped { completed = true; await stop() }
            return
        }
        completed = true
        let completedGeneration = await stop()
        guard generation == completedGeneration else { return }
        guard let series = item.SeriesId else { return }
        do {
            var episodes: [MediaItem] = []; var offset = 0
            while true {
                let page = try await api.items(user: account.userID, route: .episodes(series), start: offset)
                episodes += page.Items; offset += page.Items.count
                if page.Items.isEmpty || offset >= (page.TotalRecordCount ?? offset) { break }
            }
            let ordered = episodes.sorted { ($0.ParentIndexNumber ?? 0, $0.IndexNumber ?? 0) < ($1.ParentIndexNumber ?? 0, $1.IndexNumber ?? 0) }
            guard generation == completedGeneration, !countdown.cancelled else { return }
            guard let index = ordered.firstIndex(where: { $0.Id == item.Id }), index + 1 < ordered.count else { return }
            next = ordered[index + 1]; countdown = .init()
            countdownTask = Task { @MainActor [weak self] in
                for _ in 0..<5 {
                    do { try await Task.sleep(for: .seconds(1)) } catch { return }
                    guard let self, !self.countdown.cancelled else { return }
                    if self.countdown.tick(), let next = self.next {
                        self.countdownTask = nil
                        await self.open(next, model: model); return
                    }
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
            if let alternative = session.alternative { AlternativePlayerView(player: alternative) }
            if let segment = session.activeSegment {
                Button(LocalizedStringKey(segment.Type == "Intro" ? "player.skipIntro" : "player.skipCredits")) { session.skipSegment() }
            }
            if let next = session.next {
                Text(next.Name)
                Text(String(session.countdown.remaining)).font(.largeTitle.monospacedDigit())
                Button("player.cancelNext") { session.cancelNext() }
            }
            #if os(iOS)
            if session.player != nil { AirPlayPicker().frame(width: 44, height: 44).accessibilityLabel("player.airplay") }
            #endif
        }.navigationTitle(session.currentTitle.isEmpty ? item.Name : session.currentTitle)
        .videoConversionConsent(request: $session.consentRequest, accept: session.approveVideo, decline: session.declineVideo)
        .task { await session.open(item, model: model, localURL: localURL, localSource: localSource) }
        .onDisappear { session.cancelNext(); Task { await session.stop() } }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { Task { await session.checkpoint(force: true) } }
        }
    }
}
