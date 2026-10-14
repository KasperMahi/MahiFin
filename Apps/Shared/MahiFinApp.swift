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
                } else {
                    VStack(spacing: 24) {
                        Text("error.storage")
                        Button("retry") { bootstrap.load() }
                    }.padding()
                }
            }
        }
    }
}
