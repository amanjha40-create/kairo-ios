import Combine
import Foundation

@MainActor
final class DigiLockerStore: ObservableObject {
    @Published private(set) var status: DigiLockerStatusDTO?
    @Published private(set) var trust: DigiLockerIdentityTrustDTO?
    @Published private(set) var history: DigiLockerVerificationHistoryDTO?
    @Published private(set) var issuedDocuments: [DigiLockerIssuedDocumentDTO] = []
    @Published private(set) var isLoadingSummary = false
    @Published private(set) var isLoadingInventory = false
    @Published private(set) var isConnecting = false
    @Published private(set) var isVerifying = false
    @Published private(set) var summaryError = false
    @Published private(set) var inventoryError = false
    @Published private(set) var actionErrorMessage: String?
    @Published private(set) var aadhaarState: DigiLockerAadhaarState = .idle
    @Published var aadhaarConsent = false
    @Published private(set) var aadhaarNeedsReconciliation = false
    @Published private(set) var isReconcilingAadhaar = false

    private let service: any DigiLockerServiceProtocol
    private var aadhaarTask: Task<Void, Never>?
    private var aadhaarRevision = UUID()
    private var hasLoadedSummary = false
    private(set) var identityRevision = UUID()

    init(service: any DigiLockerServiceProtocol) {
        self.service = service
    }

    var verifiedDigiLockerSources: [DigiLockerTrustSourceDTO] {
        trust?.sources.filter {
            $0.source == .digilocker && $0.current &&
                ($0.documentType != "EAADHAAR" || savedAadhaar?.isVerified == true)
        } ?? []
    }

    var attentionDigiLockerSources: [DigiLockerTrustSourceDTO] {
        trust?.sources.filter { $0.source == .digilocker && !$0.current } ?? []
    }

    var identityIsVerified: Bool { trust?.state == .verified }
    var identityVerifiedViaDigiLocker: Bool { !verifiedDigiLockerSources.isEmpty }
    var actionInProgress: Bool { isConnecting || isVerifying || aadhaarState.isBusy || isReconcilingAadhaar }
    var savedAadhaar: DigiLockerVerificationDTO? {
        history?.items.first { $0.documentType == "EAADHAAR" }
    }

    func loadSummaryIfNeeded() async {
        guard !hasLoadedSummary else { return }
        await refreshSummary()
    }

    func refreshSummary() async {
        guard !isLoadingSummary else { return }
        let revision = identityRevision
        isLoadingSummary = true
        summaryError = false
        do {
            async let loadedStatus = service.status()
            async let loadedTrust = service.identityTrust()
            async let loadedHistory = service.verificationHistory()
            let result = try await (loadedStatus, loadedTrust, loadedHistory)
            guard revision == identityRevision else { return }
            if let previous = status, previous != result.0 {
                if isReconcilingAadhaar {
                    aadhaarConsent = false
                    if !result.0.connected { aadhaarState = .reconnectRequired }
                } else { cancelAadhaarOperation() }
            }
            status = result.0
            trust = result.1
            history = result.2
            hasLoadedSummary = true
        } catch {
            guard revision == identityRevision else { return }
            summaryError = true
        }
        isLoadingSummary = false
    }

    func refreshAll() async {
        await refreshSummary()
        if status?.connected == true { await refreshInventory() }
        else {
            issuedDocuments = []
            inventoryError = false
        }
    }

    func refreshInventory() async {
        guard status?.connected == true, !isLoadingInventory else { return }
        let revision = identityRevision
        isLoadingInventory = true
        inventoryError = false
        do {
            let response = try await service.issuedDocuments()
            guard revision == identityRevision else { return }
            issuedDocuments = uniqueDocuments(response.items)
        } catch {
            guard revision == identityRevision else { return }
            inventoryError = true
        }
        isLoadingInventory = false
    }

    func startConnection() async -> URL? {
        guard !actionInProgress, !aadhaarNeedsReconciliation, !summaryError, status?.status != .pending else { return nil }
        cancelAadhaarOperation()
        let revision = identityRevision
        isConnecting = true
        actionErrorMessage = nil
        defer { if revision == identityRevision { isConnecting = false } }
        do {
            let response = try await service.connect()
            guard revision == identityRevision else { return nil }
            let url = try DigiLockerAuthorizationURLValidator.validate(response.authorizationURL)
            status = DigiLockerStatusDTO(connected: false, status: response.connectionState)
            return url
        } catch {
            guard revision == identityRevision else { return nil }
            actionErrorMessage = "We couldn't open DigiLocker. Refresh the status before trying again."
            return nil
        }
    }

    func verify(_ types: Set<DigiLockerDocumentType>) async -> Bool {
        guard status?.connected == true, !summaryError, !aadhaarNeedsReconciliation, !types.isEmpty, !actionInProgress else { return false }
        let revision = identityRevision
        isVerifying = true
        actionErrorMessage = nil
        defer { if revision == identityRevision { isVerifying = false } }
        do {
            let response = try await service.verify(documentTypes: DigiLockerDocumentType.allCases.filter(types.contains))
            guard revision == identityRevision, !Task.isCancelled else { return false }
            history = response
            await refreshSummary()
            return true
        } catch {
            guard revision == identityRevision, !Task.isCancelled else { return false }
            actionErrorMessage = "Verification could not be completed. Review saved results before trying again."
            return false
        }
    }

    func clearActionError() { actionErrorMessage = nil }

    func checkAadhaarAvailability() async {
        guard status?.connected == true, !summaryError, !aadhaarNeedsReconciliation, !isLoadingSummary, !actionInProgress else { return }
        cancelAadhaarOperation()
        let operation = aadhaarRevision
        aadhaarState = .checking
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let availability = try await service.aadhaarAvailability()
                guard operation == aadhaarRevision, !Task.isCancelled else { return }
                aadhaarState = availability.available ? .available : .notLinked
            } catch {
                guard operation == aadhaarRevision, !Task.isCancelled else { return }
                aadhaarState = .from(error: error)
                if aadhaarState == .reconnectRequired { await reconcileAadhaarSavedResults() }
            }
        }
        aadhaarTask = task
        await task.value
        if operation == aadhaarRevision { aadhaarTask = nil }
    }

    func verifyAadhaar() async -> Bool {
        guard aadhaarConsent, aadhaarState == .available, status?.connected == true,
              !summaryError, !aadhaarNeedsReconciliation, !isLoadingSummary, !actionInProgress else { return false }
        aadhaarConsent = false
        let operation = aadhaarRevision
        aadhaarState = .verifying
        aadhaarNeedsReconciliation = true
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await service.verifyAadhaar()
                guard operation == aadhaarRevision, !Task.isCancelled else { return }
                let retained = history?.items.filter { $0.documentType != "EAADHAAR" } ?? []
                history = .init(items: retained + [result], identityVerified: history?.identityVerified ?? false)
                aadhaarState = result.isVerified ? .verified : .needsReview
            } catch {
                guard operation == aadhaarRevision, !Task.isCancelled else { return }
                aadhaarState = .from(error: error)
            }
            // Only saved backend truth is refreshed; never repeat a provider operation.
            await reconcileAadhaarSavedResults()
        }
        aadhaarTask = task
        await task.value
        guard operation == aadhaarRevision else { return false }
        aadhaarTask = nil
        return true
    }

    func cancelAadhaarOperation() {
        let interrupted = aadhaarState == .verifying || aadhaarNeedsReconciliation
        aadhaarRevision = UUID()
        aadhaarTask?.cancel()
        aadhaarTask = nil
        aadhaarConsent = false
        aadhaarState = interrupted ? .uncertain : .idle
    }

    func reconcileAadhaarSavedResults() async {
        let revision = identityRevision
        while isReconcilingAadhaar && revision == identityRevision {
            do { try await Task.sleep(for: .milliseconds(20)) } catch { return }
        }
        guard revision == identityRevision, !Task.isCancelled else { return }
        isReconcilingAadhaar = true
        defer { if revision == identityRevision { isReconcilingAadhaar = false } }
        // Wait out any older read, then fetch fresh saved truth instead of dropping it.
        while isLoadingSummary && revision == identityRevision {
            do { try await Task.sleep(for: .milliseconds(20)) } catch { return }
        }
        guard revision == identityRevision, !Task.isCancelled else { return }
        await refreshSummary()
        guard revision == identityRevision, !Task.isCancelled else { return }
        if !summaryError { aadhaarNeedsReconciliation = false }
    }

    func finishAuthentication(_ outcome: DigiLockerReturnOutcome, revision: UUID) async {
        // An initial Hub read may still be in flight. Never drop the post-return refresh.
        while (isLoadingSummary || isLoadingInventory) && revision == identityRevision {
            do { try await Task.sleep(for: .milliseconds(20)) } catch { return }
        }
        guard revision == identityRevision, !Task.isCancelled else { return }
        actionErrorMessage = outcome.message
        await refreshAll()
        // A refresh failure is shown by summaryError. Old saved provenance is retained.
    }

    func markBrowserOpenFailed() {
        actionErrorMessage = "We couldn't open the secure DigiLocker browser. Refresh the status before trying again."
    }

    func resetForIdentityChange() {
        cancelAadhaarOperation()
        aadhaarNeedsReconciliation = false
        isReconcilingAadhaar = false
        aadhaarState = .idle
        identityRevision = UUID()
        isLoadingSummary = false
        isLoadingInventory = false
        isConnecting = false
        isVerifying = false
        status = nil
        trust = nil
        history = nil
        issuedDocuments = []
        summaryError = false
        inventoryError = false
        actionErrorMessage = nil
        hasLoadedSummary = false
    }

    private func uniqueDocuments(_ documents: [DigiLockerIssuedDocumentDTO]) -> [DigiLockerIssuedDocumentDTO] {
        var seen = Set<String>()
        return documents.filter { seen.insert($0.documentType).inserted }
    }
}
