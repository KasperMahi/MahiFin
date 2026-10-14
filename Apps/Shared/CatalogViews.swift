import SwiftUI
import UIKit
import MahiFinCore

struct PosterView: View {
    @EnvironmentObject private var model: AppModel
    let item: MediaItem
    @State private var image: UIImage?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08))
                if let image { Image(uiImage: image).resizable().scaledToFill() }
                else { Image(systemName: "film").font(.largeTitle).foregroundStyle(.secondary) }
            }.frame(width: posterWidth, height: posterWidth * 1.5).clipShape(RoundedRectangle(cornerRadius: 14))
            Text(item.Name).font(.headline).lineLimit(2).frame(width: posterWidth, alignment: .leading)
            if item.UserData?.Played == true { Label("detail.watched", systemImage: "checkmark.circle").font(.caption) }
            else if item.position > 0 { ProgressView(value: item.position, total: max(item.position, Double(item.RunTimeTicks ?? 0) / 10_000_000)).tint(.mint) }
        }
        .accessibilityElement(children: .combine)
        .task(id: item.Id) {
            do {
                guard let request = try model.client().artwork(item: item) else { return }
                let (data, response) = try await URLSessionTransport().send(request)
                try Task.checkCancellation()
                if response.statusCode == 200 { image = UIImage(data: data) }
            } catch { /* Missing art is a supported visual state. */ }
        }
    }
    private var posterWidth: CGFloat {
        #if os(tvOS)
        return 220
        #else
        return 140
        #endif
    }
}
struct PosterRow: View {
    let title: LocalizedStringKey
    let items: [MediaItem]
    var resume = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.title2.bold())
            if items.isEmpty { Text("catalog.empty").foregroundStyle(.secondary) }
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 24) {
                    ForEach(items) { item in
                        if resume { NavigationLink { PlaybackView(item: item) } label: { PosterView(item: item) } }
                        else { NavigationLink { DetailView(item: item) } label: { PosterView(item: item) } }
                    }
                }.padding(8)
            }
        }
    }
}
struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var resume: [MediaItem] = []
    @State private var next: [MediaItem] = []
    @State private var recent: [MediaItem] = []
    @State private var loading = true
    @State private var failed = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text("home.welcome").font(.largeTitle.bold())
                if loading { ProgressView("catalog.loading") }
                else if failed { Button("retry") { Task { await load() } } }
                else {
                    PosterRow(title: "home.continue", items: resume, resume: true)
                    PosterRow(title: "home.next", items: next)
                    PosterRow(title: "home.recent", items: recent)
                }
            }.padding(24)
        }.navigationTitle("MahiFin").task { await load() }
        .toolbar { Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }.accessibilityLabel("refresh") }
    }
    private func load() async {
        loading = true; defer { loading = false }
        do {
            guard let account = model.active else { return }
            let api = try model.client()
            async let a = api.items(user: account.userID, route: .resume)
            async let b = api.items(user: account.userID, route: .nextUp)
            async let c = api.items(user: account.userID, route: .recent)
            let values = try await (a,b,c)
            try Task.checkCancellation()
            resume = values.0.Items; next = values.1.Items; recent = values.2.Items; failed = false
        } catch { failed = true; model.show(error) }
    }
}
struct CatalogView: View {
    @EnvironmentObject private var model: AppModel
    let kind: CatalogRoute
    let title: LocalizedStringKey
    @State private var items: [MediaItem] = []
    @State private var libraries: [MediaItem] = []
    @State private var genre = ""
    @State private var year = ""
    @State private var library = ""
    @State private var unplayed = false
    @State private var sort = "SortName"
    @State private var offset = 0
    @State private var total = 0
    @State private var loading = false
    @State private var failed = false
    private var filterKey: String { [genre,year,library,String(unplayed),sort].joined(separator: "|") }
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    TextField("filter.genre", text: $genre)
                    TextField("filter.year", text: $year)
                }
                Picker("filter.library", selection: $library) {
                    Text("filter.all").tag("")
                    ForEach(libraries) { Text($0.Name).tag($0.Id) }
                }
                Picker("filter.sort", selection: $sort) {
                    Text("filter.name").tag("SortName")
                    Text("filter.newest").tag("DateCreated")
                    Text("filter.year").tag("ProductionYear")
                }
                Toggle("filter.unwatched", isOn: $unplayed)
                if loading && items.isEmpty { ProgressView("catalog.loading") }
                if !loading && items.isEmpty { Text("catalog.empty") }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: gridMinimum), spacing: 24)], spacing: 28) {
                    ForEach(items) { item in NavigationLink { DetailView(item: item) } label: { PosterView(item: item) } }
                }
                if failed { Button("retry") { Task { await load(reset: true) } } }
                if offset < total { Button("catalog.more") { Task { await load(reset: false) } }.disabled(loading) }
            }.padding(24)
        }.navigationTitle(title)
        .task(id: filterKey) { await load(reset: true) }
    }
    private var gridMinimum: CGFloat {
        #if os(tvOS)
        return 240
        #else
        return 150
        #endif
    }
    private func load(reset: Bool) async {
        if reset { items = []; offset = 0; total = 0 }
        loading = true; defer { loading = false }
        do {
            guard let account = model.active else { return }
            let api = try model.client()
            var filter = CatalogFilter(); filter.genre = genre; filter.year = year; filter.library = library
            filter.unplayed = unplayed; filter.sort = sort
            let page = try await api.items(user: account.userID, route: kind, filter: filter, start: offset)
            try Task.checkCancellation()
            let existing = Set(items.map(\.Id)); items += page.Items.filter { !existing.contains($0.Id) }
            offset += page.Items.count; total = page.Items.isEmpty ? offset : (page.TotalRecordCount ?? offset)
            if libraries.isEmpty { libraries = try await api.items(user: account.userID, route: .views).Items }
            failed = false
        } catch { failed = true; model.show(error) }
    }
}
struct SearchView: View {
    @EnvironmentObject private var model: AppModel
    @State private var query = ""
    @State private var items: [MediaItem] = []
    @State private var loading = false
    var body: some View {
        List {
            if loading { ProgressView() }
            if items.isEmpty && !loading { Text("catalog.empty") }
            ForEach(items) { item in NavigationLink(item.Name) { DetailView(item: item) } }
        }.navigationTitle("nav.search").searchable(text: $query)
        .task(id: query) {
            items = []
            guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            loading = true; defer { loading = false }
            do {
                try await Task.sleep(for: .milliseconds(350))
                guard let account = model.active else { return }
                let values = try await model.client().items(user: account.userID, route: .search(query))
                try Task.checkCancellation(); items = values.Items
            } catch { model.show(error) }
        }
    }
}
struct DetailView: View {
    @EnvironmentObject private var model: AppModel
    let item: MediaItem
    @State private var detail: MediaItem?
    @State private var episodes: [MediaItem] = []
    @State private var busy = false
    @State private var downloadWarning = false
    private var current: MediaItem { detail ?? item }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PosterView(item: current)
                Text(current.Name).font(.largeTitle.bold())
                if let year = current.ProductionYear { Text(String(year)).foregroundStyle(.secondary) }
                if let rating = current.CommunityRating { Label(String(format: "%.1f", rating), systemImage: "star.fill") }
                Text(current.Overview ?? NSLocalizedString("detail.noOverview", comment: ""))
                if current.Type != "Series" {
                    NavigationLink { PlaybackView(item: current) } label: { Label(current.position > 0 ? "player.resume" : "player.play", systemImage: "play.fill") }
                }
                Button(current.UserData?.Played == true ? "detail.unwatch" : "detail.watch") { mutate(favorite: false) }.disabled(busy)
                Button(current.UserData?.IsFavorite == true ? "detail.unfavorite" : "detail.favorite") { mutate(favorite: true) }.disabled(busy)
                #if os(iOS)
                if current.Type != "Series" { Button("download.original") { downloadWarning = true } }
                #endif
                if let people = current.People, !people.isEmpty {
                    Text("detail.cast").font(.title2.bold())
                    ForEach(Array(people.prefix(20).enumerated()), id: \.offset) { _, person in
                        Text(person.Name + (person.Role.map { " · " + $0 } ?? ""))
                    }
                }
                if current.Type == "Series" {
                    Text("detail.episodes").font(.title2.bold())
                    ForEach(episodes) { episode in
                        NavigationLink { DetailView(item: episode) } label: {
                            Text("\(episode.ParentIndexNumber ?? 0) · \(episode.IndexNumber ?? 0)  \(episode.Name)")
                        }
                    }
                }
            }.padding(24)
        }.navigationTitle(current.Name).task { await refresh() }
        #if os(iOS)
        .alert("download.original", isPresented: $downloadWarning) {
            Button("cancel", role: .cancel) {}
            Button("download.start") { Task { await download() } }
        } message: { Text("download.warning") }
        #endif
    }
    private func refresh() async {
        do {
            guard let account = model.active else { return }
            detail = try await model.client().item(user: account.userID, id: item.Id)
            if current.Type == "Series" {
                var start = 0; var all: [MediaItem] = []
                repeat {
                    let page = try await model.client().items(user: account.userID, route: .episodes(item.Id), start: start)
                    all += page.Items; start += page.Items.count
                    if page.Items.isEmpty || start >= (page.TotalRecordCount ?? start) { break }
                } while !Task.isCancelled
                episodes = all.sorted { ($0.ParentIndexNumber ?? 0, $0.IndexNumber ?? 0) < ($1.ParentIndexNumber ?? 0, $1.IndexNumber ?? 0) }
            }
        } catch { model.show(error) }
    }
    private func mutate(favorite: Bool) {
        busy = true
        Task {
            defer { busy = false }
            do {
                guard let account = model.active else { return }
                let api = try model.client()
                if favorite { try await api.setFavorite(user: account.userID, item: item.Id, favorite: current.UserData?.IsFavorite != true) }
                else { try await api.setPlayed(user: account.userID, item: item.Id, played: current.UserData?.Played != true) }
                await refresh()
            } catch { model.show(error) }
        }
    }
    #if os(iOS)
    private func download() async {
        do {
            guard let account = model.active else { return }
            let api = try model.client()
            let info = try await api.playbackInfo(user: account.userID, item: item.Id)
            guard info.MediaSources.count == 1, let source = info.MediaSources.first else { throw ClientError.unavailable }
            // Only native-playable originals accepted while local alternative engine is unavailable.
            guard PlaybackPolicy.decide(source, device: .init()).route == .direct else { throw ClientError.unavailable }
            try model.downloads.enqueue(account: account, item: current, source: source, request: api.originalRequest(item: item.Id), cellular: model.cellularDownloads)
        } catch { model.show(error) }
    }
    #endif
}
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        Form {
            Section("profiles.choose") {
                ForEach(model.accounts) { account in
                    Button(account.name) { do { try model.select(account) } catch { model.show(error) } }
                    Button("profiles.logout", role: .destructive) { Task { await model.forget(account) } }
                }
                Button("profiles.add") { model.addingAccount = true }
                Button("profiles.chooser") { model.active = nil }
            }
            Section("settings.playback") { Text("settings.policy"); Text("settings.hardware") }
            #if os(iOS)
            Section("nav.downloads") {
                Toggle("download.cellular", isOn: Binding(get: { model.cellularDownloads }, set: { model.setCellularDownloads($0) }))
            }
            Section("settings.cast") { Text("settings.castBlocked") }
            #endif
            Section("settings.advanced") {
                Button("settings.sync") { Task { await model.sync() } }
                #if os(iOS)
                ShareLink(item: model.diagnostic.export()) { Label("settings.export", systemImage: "square.and.arrow.up") }
                #else
                Text(model.diagnostic.export()).font(.caption.monospaced())
                #endif
                Text("settings.privacy")
            }
        }.navigationTitle("nav.settings")
    }
}
