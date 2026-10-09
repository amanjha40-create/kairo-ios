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

    private let service: any DigiLockerServiceProtocol
    private var hasLoadedSummary = false
    private(set) var identityRevision = UUID()

    init(service: any DigiLockerServiceProtocol) {
        self.service = service
    }

    var verifiedDigiLockerSources: [DigiLockerTrustSourceDTO] {
        trust?.sources.filter { $0.source == .digilocker && $0.current } ?? []
    }

    var attentionDigiLockerSources: [DigiLockerTrustSourceDTO] {
        trust?.sources.filter { $0.source == .digilocker && !$0.current } ?? []
    }

    var identityIsVerified: Bool { trust?.state == .verified }
    var identityVerifiedViaDigiLocker: Bool { !verifiedDigiLockerSources.isEmpty }

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
        guard !isConnecting else { return nil }
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
        guard status?.connected == true, !types.isEmpty, !isVerifying else { return false }
        isVerifying = true
        actionErrorMessage = nil
        defer { isVerifying = false }
        do {
            history = try await service.verify(documentTypes: DigiLockerDocumentType.allCases.filter(types.contains))
            await refreshSummary()
            return true
        } catch {
            actionErrorMessage = "Verification could not be completed. Review saved results before trying again."
            return false
        }
    }

    func clearActionError() { actionErrorMessage = nil }

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
