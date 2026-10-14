import SwiftUI
import MahiFinCore

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        Group {
            if let account = model.active {
                MainTabs().id(account.id)
            } else if model.accounts.isEmpty {
                OnboardingView()
            } else {
                ProfileView()
            }
        }
        .sheet(isPresented: $model.addingAccount) { OnboardingView() }
        .alert("error.title", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("ok") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
}
struct ProfileView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Text("MahiFin").font(.largeTitle.bold()).foregroundStyle(.mint)
                Text("profiles.choose").font(.title)
                ForEach(model.accounts) { account in
                    Button { do { try model.select(account) } catch { model.show(error) } } label: {
                        Label(account.name, systemImage: "person.crop.circle.fill").font(.title2).padding()
                    }
                }
                Button("profiles.add") { model.addingAccount = true }
            }.padding()
        }
    }
}
struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var server = ""
    @State private var username = ""
    @State private var password = ""
    @State private var busy = false
    @State private var code: String?
    @State private var operation: Task<Void, Never>?
    var body: some View {
        NavigationStack {
            Form {
                Section { Text("onboarding.help") }
                Section("onboarding.server") {
                    TextField("onboarding.url", text: $server)
                        #if os(iOS)
                        .textInputAutocapitalization(.never).keyboardType(.URL).autocorrectionDisabled()
                        #endif
                }
                Section("onboarding.password") {
                    TextField("onboarding.username", text: $username)
                        #if os(iOS)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        #endif
                    SecureField("onboarding.password", text: $password)
                    Button("onboarding.signin") { run(quick: false) }.disabled(busy || username.isEmpty || server.isEmpty)
                }
                Section("onboarding.quick") {
                    if let code { Text(code).font(.largeTitle.monospaced()); Text("onboarding.authorize") }
                    Button("onboarding.quick") { run(quick: true) }.disabled(busy || server.isEmpty)
                    if busy {
                        ProgressView()
                        Button("cancel") { operation?.cancel(); busy = false; code = nil }
                    }
                }
                if !model.accounts.isEmpty { Button("cancel") { dismiss() } }
            }.navigationTitle("MahiFin")
        }.onDisappear { operation?.cancel(); password = "" }
    }
    private func run(quick: Bool) {
        busy = true
        operation = Task { @MainActor in
            defer { busy = false; password = ""; code = nil }
            do {
                guard let url = URL(string: server.trimmingCharacters(in: .whitespacesAndNewlines)) else { throw ClientError.invalidServer }
                let api = try JellyfinClient(server: url, deviceID: model.deviceID)
                let info = try await api.systemInfo()
                let auth: AuthResponse
                if quick {
                    let initial = try await api.beginQuickConnect(); code = initial.Code
                    var authenticated = false
                    for _ in 0..<60 {
                        try Task.checkCancellation()
                        try await Task.sleep(for: .seconds(2))
                        if try await api.pollQuickConnect(secret: initial.Secret).Authenticated { authenticated = true; break }
                    }
                    guard authenticated else { throw ClientError.unavailable }
                    auth = try await api.finishQuickConnect(secret: initial.Secret)
                } else { auth = try await api.authenticate(username: username, password: password) }
                try Task.checkCancellation()
                try model.link(server: url, info: info, auth: auth); dismiss()
            } catch { model.show(error) }
        }
    }
}
struct MainTabs: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }.tabItem { Label("nav.home", systemImage: "house") }
            NavigationStack { CatalogView(kind: .movies, title: "nav.films") }.tabItem { Label("nav.films", systemImage: "film") }
            NavigationStack { CatalogView(kind: .series, title: "nav.series") }.tabItem { Label("nav.series", systemImage: "tv") }
            NavigationStack { SearchView() }.tabItem { Label("nav.search", systemImage: "magnifyingglass") }
            #if os(iOS)
            NavigationStack { DownloadsView() }.tabItem { Label("nav.downloads", systemImage: "arrow.down.circle") }
            #endif
            NavigationStack { SettingsView() }.tabItem { Label("nav.settings", systemImage: "gear") }
        }
    }
}
