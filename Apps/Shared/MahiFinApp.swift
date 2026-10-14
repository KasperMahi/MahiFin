import SwiftUI

@main struct MahiFinApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase
    #if os(iOS)
    @UIApplicationDelegateAdaptor(MobileAppDelegate.self) private var appDelegate
    #endif
    var body: some Scene {
        WindowGroup {
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
}
