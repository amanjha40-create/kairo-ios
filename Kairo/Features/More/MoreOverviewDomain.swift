import Foundation

struct MoreOverview: Equatable, Sendable {
    let user: AppUser
    let trustScoreConsent: MoreTrustScoreConsent
    let notificationPreferences: [MoreNotificationSetting]
    let bundleAppVersion: String
    let backendAppVersion: String
    let apiVersion: String
    let trustScoreVersion: String
}

struct MoreTrustScoreConsent: Equatable, Sendable {
    let status: String
    let version: String?
    let consentedAt: Date?
}

struct MoreNotificationSetting: Equatable, Identifiable, Sendable {
    let id: String
    let eventType: String
    let enabled: Bool
    let preferredChannels: [String]
    let quietHours: [String: String]
    let metadata: [String: String]
    let createdAt: Date
    let updatedAt: Date
}

struct MoreSessionRecord: Equatable, Identifiable, Sendable {
    let id: String
    let createdAt: Date
    let expiresAt: Date
    let lastActiveAt: Date
    let isCurrent: Bool
}

struct MoreProfileDraft: Equatable, Sendable {
    var fullName: String
    var professionalHeadline: String
    var currentRole: String
    var industry: String
    var yearsOfExperience: String
    var currentCity: String
    var currentCountry: String

    init(
        fullName: String,
        professionalHeadline: String,
        currentRole: String,
        industry: String,
        yearsOfExperience: String,
        currentCity: String,
        currentCountry: String
    ) {
        self.fullName = fullName
        self.professionalHeadline = professionalHeadline
        self.currentRole = currentRole
        self.industry = industry
        self.yearsOfExperience = yearsOfExperience
        self.currentCity = currentCity
        self.currentCountry = currentCountry
    }
}

extension MoreProfileDraft {
    init(user: AppUser) {
        self.init(
            fullName: ManualProfileNormalization.normalized(user.fullName ?? ""),
            professionalHeadline: ManualProfileNormalization.normalized(
                user.headline ?? user.currentRole ?? ""
            ),
            currentRole: ManualProfileNormalization.normalized(user.currentRole ?? ""),
            industry: ManualProfileNormalization.normalized(user.industry ?? ""),
            yearsOfExperience: user.yearsOfExperience.map(String.init) ?? "",
            currentCity: ManualProfileNormalization.normalized(user.locationCity ?? ""),
            currentCountry: ManualProfileNormalization.normalized(user.locationCountry ?? "")
        )
    }
}

extension MoreOverview {
    nonisolated init(dto: AccountSettingsResponseDTO, bundleAppVersion: String) {
        user = dto.profile.asDomainModel()
        trustScoreConsent = MoreTrustScoreConsent(
            status: dto.trustScoreConsent.status,
            version: dto.trustScoreConsent.version,
            consentedAt: dto.trustScoreConsent.consentedAt
        )
        notificationPreferences = dto.notificationPreferences.map {
            MoreNotificationSetting(
                id: $0.publicID,
                eventType: $0.eventType,
                enabled: $0.enabled,
                preferredChannels: $0.preferredChannels,
                quietHours: $0.quietHours,
                metadata: $0.metadata,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt
            )
        }
        self.bundleAppVersion = bundleAppVersion
        backendAppVersion = dto.appVersion
        apiVersion = dto.apiVersion
        trustScoreVersion = dto.trustScoreVersion
    }
}

extension MoreSessionRecord {
    nonisolated init(dto: AccountSessionResponseDTO) {
        id = dto.id
        createdAt = dto.createdAt
        expiresAt = dto.expiresAt
        lastActiveAt = dto.lastActiveAt
        isCurrent = dto.current
    }
}
