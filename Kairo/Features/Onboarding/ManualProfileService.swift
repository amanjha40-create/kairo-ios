import Foundation

protocol ManualProfileServiceProtocol: Sendable {
    func submit(draft: ManualProfileFlowState) async throws -> ManualProfileSubmissionResult
}

nonisolated struct ManualProfileSubmissionResult: Sendable {
    let user: AppUser
    let onboardingStatus: OnboardingStatusResponseDTO
}

nonisolated enum ManualProfileSubmissionFailureStep: Equatable, Sendable {
    case basicProfile
    case employment(entryID: Int)
    case education(entryID: Int)
    case completion
}

nonisolated enum ManualProfileSubmissionError: Error, Equatable, Sendable {
    case missingRequiredAccountData(String)
    case fieldValidation(
        step: ManualProfileSubmissionFailureStep,
        fieldErrors: [String: String],
        message: String
    )
    case onboardingIncomplete(OnboardingStatusResponseDTO)
}

actor ManualProfileService: ManualProfileServiceProtocol {
    private let authService: any AuthServiceProtocol
    private let sessionService: any SessionServiceProtocol
    private let decoder = APIJSONCoder.makeDecoder()

    init(
        authService: any AuthServiceProtocol,
        sessionService: any SessionServiceProtocol
    ) {
        self.authService = authService
        self.sessionService = sessionService
    }

    func submit(
        draft: ManualProfileFlowState
    ) async throws -> ManualProfileSubmissionResult {
        let currentUser = try await authService.currentUser().asDomainModel()
        let payloads: ManualProfileSubmissionPayloads

        do {
            payloads = try ManualProfileMapper.makeSubmissionPayloads(
                draft: draft,
                currentUser: currentUser
            )
        } catch let error as ManualProfileMappingError {
            throw submissionError(for: error)
        }

        try await patchProfile(payloads.profile)

        var employmentTracker = DuplicateTracker(
            existing: try await loadEmployments().map {
                ManualProfileMapper.employmentFingerprint(dto: $0, currentUser: currentUser)
            }
        )
        for employment in payloads.employments {
            let fingerprint = ManualProfileMapper.employmentFingerprint(request: employment.request)
            guard !employmentTracker.consumeMatch(for: fingerprint) else {
                continue
            }

            try await createEmployment(employment)
        }

        var educationTracker = DuplicateTracker(
            existing: try await loadEducations().map(ManualProfileMapper.educationFingerprint)
        )
        for education in payloads.educations {
            let fingerprint = ManualProfileMapper.educationFingerprint(request: education.request)
            guard !educationTracker.consumeMatch(for: fingerprint) else {
                continue
            }

            try await createEducation(education)
        }

        try await completeOnboarding()

        let updatedUser = try await authService.currentUser().asDomainModel()
        let onboardingStatus = try await authService.onboardingStatus()

        guard onboardingStatus.isOnboardingComplete else {
            throw ManualProfileSubmissionError.onboardingIncomplete(onboardingStatus)
        }

        return ManualProfileSubmissionResult(
            user: updatedUser,
            onboardingStatus: onboardingStatus
        )
    }

    private func patchProfile(_ payload: OnboardingProfileUpdateRequestDTO) async throws {
        do {
            _ = try await send(
                NetworkRequest(
                    path: "/users/me",
                    method: .patch,
                    headers: [
                        "Accept": "application/json",
                        "Content-Type": "application/json"
                    ],
                    body: try APIJSONCoder.makeEncoder().encode(payload)
                ),
                responseType: UserPublicDTO.self
            )
        } catch let error as NetworkError {
            throw validationAwareError(
                error,
                step: .basicProfile
            )
        }
    }

    private func createEmployment(
        _ item: ManualProfileSubmissionPayloads.EmploymentItem
    ) async throws {
        do {
            _ = try await send(
                NetworkRequest(
                    path: "/employments/",
                    method: .post,
                    headers: [
                        "Accept": "application/json",
                        "Content-Type": "application/json"
                    ],
                    body: try APIJSONCoder.makeEncoder().encode(item.request)
                ),
                responseType: ManualCreatedRecordDTO.self
            )
        } catch let error as NetworkError {
            throw validationAwareError(
                error,
                step: .employment(entryID: item.entryID)
            )
        }
    }

    private func createEducation(
        _ item: ManualProfileSubmissionPayloads.EducationItem
    ) async throws {
        do {
            _ = try await send(
                NetworkRequest(
                    path: "/educations",
                    method: .post,
                    headers: [
                        "Accept": "application/json",
                        "Content-Type": "application/json"
                    ],
                    body: try APIJSONCoder.makeEncoder().encode(item.request)
                ),
                responseType: ManualCreatedRecordDTO.self
            )
        } catch let error as NetworkError {
            throw validationAwareError(
                error,
                step: .education(entryID: item.entryID)
            )
        }
    }

    private func completeOnboarding() async throws {
        do {
            _ = try await sessionService.sendAuthenticated(
                NetworkRequest(
                    path: "/users/me/complete-onboarding",
                    method: .post,
                    headers: ["Accept": "application/json"]
                )
            )
        } catch let error as NetworkError {
            throw validationAwareError(error, step: .completion)
        }
    }

    private func loadEmployments() async throws -> [CareerEmploymentDTO] {
        try await loadCollection([CareerEmploymentDTO].self, path: "/employments/")
    }

    private func loadEducations() async throws -> [CareerEducationDTO] {
        try await loadCollection([CareerEducationDTO].self, path: "/educations")
    }

    private func loadCollection<Element: Decodable & Equatable & Sendable>(
        _ type: [Element].Type,
        path: String
    ) async throws -> [Element] {
        let data = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: path,
                headers: ["Accept": "application/json"]
            )
        )

        do {
            return try decoder.decode([Element].self, from: data)
        } catch {
            return try decoder.decode(CareerCollectionEnvelopeDTO<Element>.self, from: data).items
        }
    }

    private func send<Response: Decodable>(
        _ request: NetworkRequest,
        responseType: Response.Type
    ) async throws -> Response {
        let data = try await sessionService.sendAuthenticated(request)
        return try decoder.decode(responseType, from: data)
    }

    private func validationAwareError(
        _ error: NetworkError,
        step: ManualProfileSubmissionFailureStep
    ) -> Error {
        guard case .api(let apiError) = error, apiError.code == .validationError else {
            return error
        }

        let flattenedFieldErrors = apiError.fieldErrors.reduce(into: [String: String]()) { partialResult, pair in
            partialResult[pair.key] = pair.value.first
        }

        return ManualProfileSubmissionError.fieldValidation(
            step: step,
            fieldErrors: flattenedFieldErrors,
            message: apiError.globalErrors.first ?? apiError.message
        )
    }

    private func submissionError(for error: ManualProfileMappingError) -> ManualProfileSubmissionError {
        switch error {
        case .missingFullName:
            return .missingRequiredAccountData(
                "Enter your full name before you continue building your Trust Passport."
            )
        case .basic(let field, let message):
            return .fieldValidation(
                step: .basicProfile,
                fieldErrors: [profileFieldKey(for: field): message],
                message: message
            )
        case .employment(let entryID, let field, let message):
            return .fieldValidation(
                step: .employment(entryID: entryID),
                fieldErrors: [employmentFieldKey(for: field): message],
                message: message
            )
        case .education(let entryID, let field, let message):
            return .fieldValidation(
                step: .education(entryID: entryID),
                fieldErrors: [educationFieldKey(for: field): message],
                message: message
            )
        }
    }

    private func profileFieldKey(for field: ManualProfileBasicField) -> String {
        switch field {
        case .fullName:
            "full_name"
        case .professionalHeadline:
            "headline"
        case .currentRole:
            "current_role"
        case .industry:
            "industry"
        case .yearsOfExperience:
            "years_of_experience"
        case .currentCity:
            "location_city"
        case .currentCountry:
            "location_country"
        }
    }

    private func employmentFieldKey(for field: ManualEmploymentField) -> String {
        switch field {
        case .company:
            "employer_legal_name"
        case .jobTitle:
            "job_title"
        case .employmentType:
            "employment_type"
        case .workCountry:
            "work_location_country"
        case .startDay, .startMonth, .startYear:
            "start_date"
        case .endDay, .endMonth, .endYear:
            "end_date"
        }
    }

    private func educationFieldKey(for field: ManualEducationField) -> String {
        switch field {
        case .institution:
            "institution_name"
        case .degree:
            "degree"
        case .educationLevel:
            "education_level"
        case .fieldOfStudy:
            "field_of_study"
        case .startYear:
            "start_date"
        case .endYear:
            "end_date"
        }
    }
}

actor DemoManualProfileService: ManualProfileServiceProtocol {
    private let authService: any AuthServiceProtocol

    init(authService: any AuthServiceProtocol) {
        self.authService = authService
    }

    func submit(
        draft: ManualProfileFlowState
    ) async throws -> ManualProfileSubmissionResult {
        _ = draft
        return ManualProfileSubmissionResult(
            user: try await authService.currentUser().asDomainModel(),
            onboardingStatus: .fixture(
                currentStep: .complete,
                passportReady: true,
                completedSteps: ["verify_email", "verify_phone", "complete_profile"],
                completionPercentage: 100,
                isOnboardingComplete: true
            )
        )
    }
}

private nonisolated struct DuplicateTracker<Fingerprint: Hashable> {
    private var counts: [Fingerprint: Int]

    init(existing: [Fingerprint]) {
        counts = existing.reduce(into: [Fingerprint: Int]()) { partialResult, fingerprint in
            partialResult[fingerprint, default: 0] += 1
        }
    }

    mutating func consumeMatch(for fingerprint: Fingerprint) -> Bool {
        guard let currentCount = counts[fingerprint], currentCount > 0 else {
            return false
        }

        if currentCount == 1 {
            counts.removeValue(forKey: fingerprint)
        } else {
            counts[fingerprint] = currentCount - 1
        }

        return true
    }
}
