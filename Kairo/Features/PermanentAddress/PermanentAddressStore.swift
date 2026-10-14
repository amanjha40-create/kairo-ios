import Foundation
import Combine

@MainActor final class PermanentAddressStore: ObservableObject {
    @Published private(set) var state: PermanentAddressState?
    @Published private(set) var document: AddressDocumentState?
    @Published private(set) var policy: AddressDocumentPolicy?
    @Published private(set) var busy = false
    @Published private(set) var locationActive = false
    @Published private(set) var addressSaveRevision = 0
    @Published private(set) var stage: String?
    @Published private(set) var error: String?
    @Published private(set) var documentError: String?
    private let service: any PermanentAddressServing
    private let collector: any AddressLocationCollecting
    private var operation: AddressLocationOperation?
    private var task: Task<Void, Never>?
    private var generation = UUID()
    init(service: any PermanentAddressServing, collector: any AddressLocationCollecting) {
        self.service = service; self.collector = collector
    }
    func stop() {
        generation = UUID(); task?.cancel(); task = nil
        collector.cancel()
        let running = operation; operation = nil
        Task { await running?.cancel() }
        busy = false; stage = nil; locationActive = false
    }
    func cancelLocation() { let current = operation; Task { await current?.cancel() } }
    func refresh() {
        guard !busy else { return }
        run { [self] ticket in
            let next = try await service.state()
            guard generation == ticket else { return }
            apply(next)
            await loadDocument(ticket)
        }
    }
    private func apply(_ next: PermanentAddressState) {
        if next.addressVersionId != state?.addressVersionId { document = nil; documentError = nil }
        state = next
    }
    private func loadDocument(_ ticket: UUID) async {
        guard let version = state?.addressVersionId else { return }
        do {
            let next = try await service.document(version: version)
            let options = try await service.policy()
            guard generation == ticket, state?.addressVersionId == version else { return }
            document = next; policy = options; documentError = nil
        } catch {
            guard generation == ticket else { return }
            document = nil; policy = nil
            documentError = "Document status unavailable. Refresh before uploading."
        }
    }
    func save(_ address: ClaimedPermanentAddress) {
        guard address.isValid else { return }
        run { [self] ticket in
            let next = try await service.save(address)
            guard generation == ticket else { return }
            apply(next); addressSaveRevision += 1; await loadDocument(ticket)
        }
    }
    func upload(file: URL, type: String, issued: String?) {
        guard let version = state?.addressVersionId else { return }
        run { [self] ticket in
            stage = "Uploading and confirming document with KairoID..."
            let next = try await service.upload(version: version, type: type, file: file, issued: issued)
            guard generation == ticket, state?.addressVersionId == version else { return }
            document = next; documentError = nil
        }
    }
    func submitDocument(confirmed: Bool) {
        guard confirmed, let version = state?.addressVersionId, let document,
              document.status == "UPLOADED", let id = document.documentId else { return }
        run { [self] ticket in
            stage = "Submitting for review..."
            let next = try await service.submit(version: version, document: id)
            guard generation == ticket else { return }
            apply(next); await loadDocument(ticket)
        }
    }
    func locate() {
        guard !busy, let version = state?.addressVersionId, state?.canStartLocation == true else { return }
        let check = AddressLocationOperation(collector: collector, service: service)
        operation = check
        locationActive = true
        run { [self] ticket in
            do {
                let next = try await check.run(version: version) { [weak self] value in
                    guard self?.generation == ticket else { return }; self?.stage = value
                }
                guard generation == ticket else { return }
                apply(next)
                error = Self.resultMessage(next.lastLocationResult)
            } catch {
                guard generation == ticket else { return }
                self.error = (error as? AddressCollectionError)?.errorDescription ?? "We couldn't finish this check. Refresh your status before trying again."
            }
            operation = nil
            locationActive = false
            if let next = try? await service.state(), generation == ticket { apply(next) }
        }
    }
    private func run(_ body: @escaping @MainActor (UUID) async throws -> Void) {
        guard !busy else { return }
        busy = true; error = nil
        let ticket = generation
        task = Task { [weak self] in
            guard let self else { return }
            do { try await body(ticket) }
            catch {
                guard generation == ticket else { return }
                self.error = "We couldn't confirm this change. Refresh your status and review your input before trying again."
                // Read-only reconciliation after an ambiguous write; never blindly resubmit.
                if let next = try? await service.state(), generation == ticket { apply(next); await loadDocument(ticket) }
            }
            guard generation == ticket else { return }
            busy = false; stage = nil; task = nil
        }
    }
    nonisolated static func resultMessage(_ value: String?) -> String? {
        ["MATCHED":"Location confirmed", "RETRY_REQUIRED":"Couldn't get an accurate location. Try again.",
         "OUTSIDE_EXPECTED_AREA":"You're outside the expected address area.", "NEEDS_REVIEW":"We'll review this check.",
         "CANCELLED":"Location check cancelled."][value ?? ""]
    }
}
