import Combine
import Foundation

nonisolated struct ResumeDeletionTarget: Equatable, Sendable {
    let id: String
    let filename: String
}

/// Only Resume history is refreshed. This object cannot mutate Career, Trust or onboarding.
@MainActor
final class ResumeDeletionState: ObservableObject {
    @Published private(set) var confirmation: ResumeDeletionTarget?
    @Published private(set) var isDeleting = false
    @Published private(set) var message: String?
    @Published private(set) var needsReconciliation = false
    private var activeTarget: ResumeDeletionTarget?
    private var accepted = false
    private var submitting = false

    func requestConfirmation(_ target: ResumeDeletionTarget) {
        guard !isDeleting, !needsReconciliation else { return }
        confirmation = target
        message = nil
    }

    func cancel() { confirmation = nil }

    // Synchronous claim prevents a second tap/task from submitting the same confirmation.
    func beginDeletion() -> ResumeDeletionTarget? {
        guard !isDeleting, !needsReconciliation, let target = confirmation else { return nil }
        confirmation = nil
        activeTarget = target
        accepted = false
        isDeleting = true
        return target
    }

    func performDeletion(_ target: ResumeDeletionTarget, using service: any ResumeImportServiceProtocol) async -> ResumeHistoryPage? {
        guard isDeleting, !submitting, activeTarget == target else { return nil }
        submitting = true
        defer { submitting = false }
        do {
            try await service.deleteResume(resumeID: target.id)
            accepted = true
        } catch {
            // Do not display raw transport/server messages or replay DELETE, even on timeout/401.
            accepted = false
        }
        return await reconcileCurrentTarget(using: service)
    }

    func reconcile(using service: any ResumeImportServiceProtocol) async -> ResumeHistoryPage? {
        guard !isDeleting, needsReconciliation, activeTarget != nil else { return nil }
        isDeleting = true
        return await reconcileCurrentTarget(using: service)
    }

    private func reconcileCurrentTarget(using service: any ResumeImportServiceProtocol) async -> ResumeHistoryPage? {
        defer { isDeleting = false }
        guard let target = activeTarget else { return nil }
        do {
            var unavailable = false
            do { _ = try await service.restoreWorkflow(resumeID: target.id) }
            catch let error as NetworkError {
                guard case .api(let apiError) = error, apiError.statusCode == 404 else { throw error }
                unavailable = true
            }
            let page = try await service.resumeHistory(offset: 0, limit: 20)
            if unavailable && !page.entries.contains(where: { $0.resume.id == target.id }) {
                message = accepted
                    ? "Resume deleted. Imported Career records were not deleted."
                    : "This resume is no longer available. Your history has been refreshed."
                needsReconciliation = false
                activeTarget = nil
            } else if !accepted && !unavailable {
                message = "Couldn't delete this resume. It is still available. Nothing was removed locally."
                needsReconciliation = false
                activeTarget = nil
            } else {
                message = "The server has not confirmed the updated history yet. Check status before another action."
                needsReconciliation = true
            }
            return page
        } catch {
            needsReconciliation = true
            message = "Couldn't confirm the latest resume state. Check status before another action. Deletion will not be retried automatically."
            return nil
        }
    }
}
