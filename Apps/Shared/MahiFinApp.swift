import SwiftUI

@MainActor final class Bootstrap: ObservableObject {
    @Published var model: AppModel?
    init() { load() }
    func load() { model = try? AppModel() }
}
@main struct MahiFinApp: App {
    @StateObject private var bootstrap = Bootstrap()
    @Environment(\.scenePhase) private var scenePhase
    #if os(iOS)
    @UIApplicationDelegateAdaptor(MobileAppDelegate.self) private var appDelegate
    #endif
    var body: some Scene {
        WindowGroup {
            Group {
                if let model = bootstrap.model {
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("--vlc-fixture") {
                        PlaybackFixtureView().preferredColorScheme(.dark)
                    } else if ProcessInfo.processInfo.arguments.contains("--consent-fixture") {
                        ConversionConsentFixtureView().preferredColorScheme(.dark)
                    } else {
                        application(model)
                    }
                    #else
                    application(model)
                    #endif
                } else {
                    VStack(spacing: 24) {
                        Text("error.storage")
                        Button("retry") { bootstrap.load() }
                    }.padding()
                }
            }
        }
    }
    private func application(_ model: AppModel) -> some View {
                    RootView().environmentObject(model).preferredColorScheme(.dark).tint(.mint)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await model.sync() } }
                    }
                    .task {
                        while !Task.isCancelled {
                            await model.sync()
                            try? await Task.sleep(for: .seconds(30))
                        }
                    }
    }
}
