import SwiftUI

/// Publish the destination only when SwiftUI has finished dismissing initiation.
/// Otherwise a cached/offscreen Verify tab can consume the route before it can present.
private struct VerificationInitiationFlow: ViewModifier {
    @Binding var preset: VerificationInitiationPreset?
    let service: any VerificationInitiationServiceProtocol
    let onRequestReady: (String) -> Void
    @State private var pendingRequestID: String?

    func body(content: Content) -> some View {
        content.sheet(item: $preset, onDismiss: {
            guard let requestID = pendingRequestID else { return }
            pendingRequestID = nil
            onRequestReady(requestID)
        }) { preset in
            VerificationInitiationSheet(service: service, preset: preset) { requestID in
                pendingRequestID = requestID
            }
        }
    }
}

extension View {
    func verificationInitiationSheet(
        preset: Binding<VerificationInitiationPreset?>,
        service: any VerificationInitiationServiceProtocol,
        onRequestReady: @escaping (String) -> Void
    ) -> some View {
        modifier(VerificationInitiationFlow(preset: preset, service: service, onRequestReady: onRequestReady))
    }
}
