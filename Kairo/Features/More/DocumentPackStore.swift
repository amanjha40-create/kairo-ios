import Combine
import Foundation

@MainActor
final class DocumentPackStore: ObservableObject {
    enum Step: Int { case selection, purpose, expiry, review }
    @Published var step: Step = .selection
    @Published var purpose = ""
    @Published var expiryDays = DocumentPackLimits.defaultExpiryDays
    @Published var category = "all"
    @Published private(set) var documents: [PackSelectableDocument] = []
    @Published private(set) var selectedIDs: Set<String> = []
    @Published private(set) var packs: [DocumentPack] = []
    @Published private(set) var detail: DocumentPack?
    @Published private(set) var creation: DocumentPackCreation?
    @Published private(set) var loading = false
    @Published private(set) var busy = false
    @Published private(set) var error: DocumentPackError?
    @Published private(set) var ambiguous = false
    private var generation = UUID()

    var selected: [PackSelectableDocument] { documents.filter { selectedIDs.contains($0.id) } }
    var categories: [String] { ["all"] + Set(documents.map(\.category)).sorted() }
    var visible: [PackSelectableDocument] { documents.filter { category == "all" || $0.category == category } }
    var selectionValid: Bool {
        (try? DocumentPackCreate(purpose: "Validation", expiryDays: expiryDays, documents: selected)) != nil
    }
    var canContinue: Bool {
        guard !busy, !loading, selectionValid else { return false }
        return step != .purpose || DocumentPackLimits.validPurpose(purpose)
    }
    var canCreate: Bool { !busy && !ambiguous && creation == nil && selectionValid && DocumentPackLimits.validPurpose(purpose) }

    func toggle(_ doc: PackSelectableDocument) {
        guard !busy, !ambiguous, documents.contains(doc) else { return }
        error = nil
        if !selectedIDs.insert(doc.id).inserted { selectedIDs.remove(doc.id) }
    }
    func clearSelection() { if !busy && !ambiguous { selectedIDs = [] } }
    func next() { if canContinue, let next = Step(rawValue: step.rawValue + 1) { step = next; error = nil } }
    func back() { if !busy, let previous = Step(rawValue: step.rawValue - 1) { step = previous } }
    func loadDocuments(_ service: any DocumentPackServiceProtocol) async {
        guard !loading else { return }
        let generation = generation
        loading = true; error = nil
        defer { if generation == self.generation { loading = false } }
        do {
            let values = try await service.documents()
            guard generation == self.generation else { return }
            guard Set(values.map(\.id)).count == values.count else { throw DocumentPackError.connection }
            // Refresh cannot silently replace a selected file version.
            let old = Dictionary(documents.map { ($0.id, $0.selectionVersion) }, uniquingKeysWith: { first, _ in first })
            selectedIDs = Set(values.filter { selectedIDs.contains($0.id) && old[$0.id] == $0.selectionVersion }.map(\.id))
            documents = values
            if !categories.contains(category) { category = "all" }
        } catch { if generation == self.generation { self.error = .map(error) } }
    }
    func loadHistory(_ service: any DocumentPackServiceProtocol) async {
        guard !loading else { return }
        let generation = generation
        loading = true; error = nil
        defer { if generation == self.generation { loading = false } }
        do {
            let values = try await service.history()
            guard generation == self.generation else { return }
            packs = values
            if let creation, let refreshed = values.first(where: { $0.id == creation.pack.id }), !refreshed.isActive { self.creation = nil }
        } catch { if generation == self.generation { self.error = .map(error) } }
    }
    func loadDetail(_ id: String, service: any DocumentPackServiceProtocol) async {
        let generation = generation
        error = nil; detail = nil; loading = true
        defer { if generation == self.generation { loading = false } }
        do {
            let value = try await service.detail(id: id)
            guard generation == self.generation else { return }
            detail = value
            if !value.isActive, creation?.pack.id == id { creation = nil }
        } catch { if generation == self.generation { self.error = .map(error) } }
    }
    func create(_ service: any DocumentPackServiceProtocol) async {
        guard canCreate else { return }
        let generation = generation
        busy = true; error = nil
        defer { if generation == self.generation { busy = false } }
        do {
            let input = try DocumentPackCreate(purpose: purpose, expiryDays: expiryDays, documents: selected)
            let value = try await service.create(input)
            guard generation == self.generation else { return }
            creation = value
        } catch {
            guard generation == self.generation else { return }
            let mapped = DocumentPackError.map(error, creating: true)
            self.error = mapped
            ambiguous = mapped == .ambiguousCreation
        }
    }
    func revoke(_ id: String, service: any DocumentPackServiceProtocol) async {
        guard !busy else { return }
        let generation = generation
        busy = true; error = nil
        defer { if generation == self.generation { busy = false } }
        do {
            let value = try await service.revoke(id: id)
            guard generation == self.generation else { return }
            detail = value
            if creation?.pack.id == id { creation = nil }
            // Keep the server's revoke result even if the subsequent refresh is offline.
            let history = try await service.history()
            guard generation == self.generation else { return }
            packs = history
        } catch { if generation == self.generation { self.error = .map(error) } }
    }
    func endSession() {
        generation = UUID(); creation = nil; detail = nil; documents = []; packs = []; selectedIDs = []
        purpose = ""; error = nil; loading = false; busy = false; ambiguous = false
    }
    func finishCreation() { creation = nil; selectedIDs = []; purpose = ""; step = .selection }
}
