import Foundation
import Combine

@MainActor
final class ProfileOverviewStore: ObservableObject {
    @Published private(set) var snapshot: ProfileSnapshot
    @Published private(set) var isLoading = false
    @Published private(set) var isMutating = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var actionMessage: String?

    private let service: any ProfileServiceProtocol

    init(service: any ProfileServiceProtocol, initialUser: AppUser) {
        self.service = service
        snapshot = ProfileSnapshot(user: initialUser, skills: [])
    }

    func load(showLoading: Bool = true) async {
        if showLoading { isLoading = true }
        errorMessage = nil
        do {
            snapshot = try await service.load()
        } catch {
            errorMessage = "We couldn't load your profile. Please try again."
        }
        isLoading = false
    }

    func update(_ draft: ProfileEditDraft) async throws {
        try await mutate(success: "Profile updated") { try await service.update(draft) }
    }

    func uploadAvatar(_ data: Data) async throws {
        try await mutate(success: "Profile photo updated") { try await service.uploadAvatar(jpegData: data) }
    }

    func removeAvatar() async throws {
        try await mutate(success: "Profile photo removed") { try await service.removeAvatar() }
    }

    func addSkills(_ names: [String]) async throws {
        guard !names.isEmpty else { return }
        isMutating = true
        errorMessage = nil
        do {
            var current = snapshot
            for name in names {
                guard let entry = ProfileCatalogues.resolve(name, in: ProfileCatalogues.skills) else {
                    throw ProfileServiceError.invalidSkill
                }
                if !ProfileCatalogues.contains(
                    entry,
                    values: current.skills.map(\.name),
                    in: ProfileCatalogues.skills
                ) {
                    current = try await service.addSkill(name: entry.name)
                    snapshot = current
                }
            }
            actionMessage = "Skills saved"
            isMutating = false
        } catch {
            isMutating = false
            errorMessage = "Could not add all selected skills. Any saved skills are kept. Please try again."
            throw error
        }
    }

    func removeSkill(id: String) async throws {
        try await mutate(success: "Skill removed") { try await service.removeSkill(id: id) }
    }

    func addLanguage(name: String, proficiency: ProfileLanguageProficiency) async throws {
        try await mutate(success: "Language saved") {
            try await service.addLanguage(name: name, proficiency: proficiency)
        }
    }

    func updateLanguage(id: String, name: String, proficiency: ProfileLanguageProficiency) async throws {
        try await mutate(success: "Language saved") {
            try await service.updateLanguage(id: id, name: name, proficiency: proficiency)
        }
    }

    func removeLanguage(id: String) async throws {
        try await mutate(success: "Language removed") { try await service.removeLanguage(id: id) }
    }

    func addLink(type: ProfileLinkType, label: String?, url: URL) async throws {
        try await mutate(success: "Professional link saved") {
            try await service.addLink(type: type, label: label, url: url)
        }
    }

    func updateLink(id: String, type: ProfileLinkType, label: String?, url: URL) async throws {
        try await mutate(success: "Professional link saved") {
            try await service.updateLink(id: id, type: type, label: label, url: url)
        }
    }

    func removeLink(id: String) async throws {
        try await mutate(success: "Professional link removed") { try await service.removeLink(id: id) }
    }

    func clearActionMessage() { actionMessage = nil }

    private func mutate(
        success: String,
        operation: () async throws -> ProfileSnapshot
    ) async throws {
        guard !isMutating else { return }
        isMutating = true
        errorMessage = nil
        do {
            snapshot = try await operation()
            actionMessage = success
            isMutating = false
        } catch {
            isMutating = false
            errorMessage = safeMessage(for: error)
            throw error
        }
    }

    private func safeMessage(for error: Error) -> String {
        if let error = error as? ProfileServiceError {
            return error.localizedDescription
        }
        if let error = error as? NetworkError, case .api(let apiError) = error {
            switch apiError.statusCode {
            case 409: return "That item is already on your profile."
            case 422: return "Review the highlighted information and try again."
            default: break
            }
        }
        return "Your change could not be saved. Please try again."
    }
}
