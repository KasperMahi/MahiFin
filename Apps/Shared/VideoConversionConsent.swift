import SwiftUI
import MahiFinCore

private struct VideoConversionConsent: ViewModifier {
    @Binding var request: PendingVideoConsent?
    @State private var presented = false
    let accept: (PendingVideoConsent) -> Void
    let decline: () -> Void
    func body(content: Content) -> some View {
        // SwiftUI can dismiss the alert binding before invoking its button action.
        // Keep the request until the explicit action validates and consumes it.
        content.alert("player.conversionTitle", isPresented: $presented, presenting: request) { presented in
            Button("cancel", role: .cancel) { decline(); request = nil }
            Button("player.acceptConversion") { accept(presented); request = nil }
        } message: { _ in Text("player.conversionImpact") }
        .onChange(of: request?.id, initial: true) { _, identity in presented = identity != nil }
    }
}
extension View {
    func videoConversionConsent(request: Binding<PendingVideoConsent?>,
                                accept: @escaping (PendingVideoConsent) -> Void,
                                decline: @escaping () -> Void) -> some View {
        modifier(VideoConversionConsent(request: request, accept: accept, decline: decline))
    }
}
