import Combine

@MainActor
final class CandidateDataRefreshStore: ObservableObject {
    @Published private(set) var revision = 0
    @Published private(set) var focusedVerificationRequestID: String?

    func verificationRequested(requestID: String) {
        focusedVerificationRequestID = requestID
        revision += 1
    }

    func passportSharesChanged() {
        revision += 1
    }

    func clearVerificationFocus(requestID: String) {
        guard focusedVerificationRequestID == requestID else { return }
        focusedVerificationRequestID = nil
    }

    func resetAfterAccountDeletion() {
        focusedVerificationRequestID = nil
        revision += 1
    }
}
