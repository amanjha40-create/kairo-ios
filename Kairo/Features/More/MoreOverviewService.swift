import Foundation

protocol MoreOverviewServiceProtocol: Sendable {
    func loadOverview() async throws -> MoreOverview
    func updateProfile(_ draft: MoreProfileDraft) async throws -> MoreOverview
    func changePassword(
        currentPassword: String,
        newPassword: String,
        confirmPassword: String
    ) async throws -> String
    func loadSessions() async throws -> [MoreSessionRecord]
    func revokeSession(id: String) async throws
    func updateNotificationPreference(
        id: String,
        enabled: Bool,
        existingPreferences: [MoreNotificationPreferenceItem]
    ) async throws -> MoreOverview
    func withdrawTrustScoreConsent() async throws -> MoreOverview
}

actor MoreOverviewService: MoreOverviewServiceProtocol {
    private let sessionService: any SessionServiceProtocol
    private let bundleAppVersion: String

    init(
        sessionService: any SessionServiceProtocol,
        bundleAppVersion: String
    ) {
        self.sessionService = sessionService
        self.bundleAppVersion = bundleAppVersion
    }

    func loadOverview() async throws -> MoreOverview {
        let dto = try await fetchAccountSettings()
        return MoreOverview(dto: dto, bundleAppVersion: bundleAppVersion)
    }

    func updateProfile(_ draft: MoreProfileDraft) async throws -> MoreOverview {
        let request = UserUpdateRequestDTO(
            fullName: normalizedValue(draft.fullName),
            currentRole: normalizedValue(draft.currentRole),
            industry: normalizedValue(draft.industry),
            yearsOfExperience: normalizedYears(draft.yearsOfExperience),
            locationCity: normalizedValue(draft.currentCity),
            locationCountry: normalizedValue(draft.currentCountry),
            headline: normalizedValue(draft.professionalHeadline)
        )

        _ = try await sessionService.sendAuthenticated(
            jsonRequest(
                path: "/users/me",
                method: .patch,
                body: request
            )
        )

        return try await loadOverview()
    }

    func changePassword(
        currentPassword: String,
        newPassword: String,
        confirmPassword: String
    ) async throws -> String {
        let data = try await sessionService.sendAuthenticated(
            jsonRequest(
                path: "/auth/change-password",
                method: .post,
                body: ChangePasswordRequestDTO(
                    currentPassword: currentPassword,
                    newPassword: newPassword,
                    confirmPassword: confirmPassword
                )
            )
        )
        return try APIJSONCoder.makeDecoder()
            .decode(ChangePasswordResponseDTO.self, from: data)
            .message
    }

    func loadSessions() async throws -> [MoreSessionRecord] {
        let data = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: "/account/sessions",
                headers: ["Accept": "application/json"]
            )
        )
        let dto = try APIJSONCoder.makeDecoder().decode([AccountSessionResponseDTO].self, from: data)
        return dto.map(MoreSessionRecord.init)
    }

    func revokeSession(id: String) async throws {
        _ = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: "/account/sessions/\(id)",
                method: .delete,
                headers: ["Accept": "application/json"]
            )
        )
    }

    func updateNotificationPreference(
        id: String,
        enabled: Bool,
        existingPreferences: [MoreNotificationPreferenceItem]
    ) async throws -> MoreOverview {
        let payload = existingPreferences.map { preference -> NotificationPreferenceUpsertRequestDTO in
            NotificationPreferenceUpsertRequestDTO(
                eventType: preference.eventType,
                enabled: preference.id == id ? enabled : preference.isEnabled,
                preferredChannels: preference.preferredChannels.isEmpty ? nil : preference.preferredChannels,
                quietHours: preference.quietHours.isEmpty ? nil : preference.quietHours,
                metadata: preference.metadata.isEmpty ? nil : preference.metadata
            )
        }

        _ = try await sessionService.sendAuthenticated(
            jsonRequest(
                path: "/account/settings",
                method: .patch,
                body: AccountSettingsUpdateRequestDTO(
                    notificationPreferences: payload,
                    withdrawTrustScoreConsent: false
                )
            )
        )

        return try await loadOverview()
    }

    func withdrawTrustScoreConsent() async throws -> MoreOverview {
        _ = try await sessionService.sendAuthenticated(
            jsonRequest(
                path: "/account/settings",
                method: .patch,
                body: AccountSettingsUpdateRequestDTO(
                    notificationPreferences: nil,
                    withdrawTrustScoreConsent: true
                )
            )
        )

        return try await loadOverview()
    }

    private func fetchAccountSettings() async throws -> AccountSettingsResponseDTO {
        let data = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: "/account/settings",
                headers: ["Accept": "application/json"]
            )
        )
        return try APIJSONCoder.makeDecoder().decode(AccountSettingsResponseDTO.self, from: data)
    }

    private func jsonRequest<Body: Encodable>(
        path: String,
        method: HTTPMethod,
        body: Body
    ) throws -> NetworkRequest {
        NetworkRequest(
            path: path,
            method: method,
            headers: [
                "Accept": "application/json",
                "Content-Type": "application/json"
            ],
            body: try APIJSONCoder.makeEncoder().encode(body)
        )
    }

    private func normalizedValue(_ value: String) -> String? {
        let normalized = ManualProfileNormalization.normalized(value)
        return normalized.isEmpty ? nil : normalized
    }

    private func normalizedYears(_ value: String) -> Int? {
        let normalized = ManualProfileNormalization.normalized(value)
        guard !normalized.isEmpty else {
            return nil
        }

        return ManualProfileValidation.normalizedYearsOfExperience(normalized)
    }
}
