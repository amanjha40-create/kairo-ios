import Foundation

protocol CareerOverviewServiceProtocol: Sendable {
    func loadOverview() async throws -> CareerOverview
}

actor CareerOverviewService: CareerOverviewServiceProtocol {
    private let authService: any AuthServiceProtocol
    private let sessionService: any SessionServiceProtocol

    init(
        authService: any AuthServiceProtocol,
        sessionService: any SessionServiceProtocol
    ) {
        self.authService = authService
        self.sessionService = sessionService
    }

    func loadOverview() async throws -> CareerOverview {
        async let currentUserResult = captureResult { [self] in try await self.loadCurrentUser() }
        async let employmentsResult = captureResult { [self] in
            try await self.loadCollection([CareerEmploymentDTO].self, path: "/employments/")
        }
        async let educationsResult = captureResult { [self] in
            try await self.loadCollection([CareerEducationDTO].self, path: "/educations")
        }
        async let certificationsResult = captureResult { [self] in
            try await self.loadCollection([CareerCertificationDTO].self, path: "/certifications")
        }
        async let projectsResult = captureResult { [self] in
            try await self.loadCollection([CareerProjectDTO].self, path: "/projects")
        }
        async let skillsResult = captureResult { [self] in
            try await self.loadCollection([CareerSkillDTO].self, path: "/skills")
        }

        let employmentRecords = try await employmentsResult.get()
        let educationRecords = try await educationsResult.get()
        let certificationRecords = try await certificationsResult.get()
        let projectRecords = try await projectsResult.get()
        let skillRecords = try await skillsResult.get()

        return CareerOverview(
            user: try await currentUserResult.get().asDomainModel(),
            employments: employmentRecords.map(CareerEmploymentRecord.init(dto:)),
            educations: educationRecords.map(CareerEducationRecord.init(dto:)),
            certifications: certificationRecords.map(CareerCertificationRecord.init(dto:)),
            projects: projectRecords.map(CareerProjectRecord.init(dto:)),
            skills: skillRecords.map(CareerSkillRecord.init(dto:))
        )
    }

    private func captureResult<Value: Sendable>(
        _ operation: @escaping @Sendable () async throws -> Value
    ) async -> Result<Value, Error> {
        do {
            return .success(try await operation())
        } catch {
            return .failure(error)
        }
    }

    private func loadCurrentUser() async throws -> UserPublicDTO {
        do {
            return try await authService.currentUser()
        } catch {
            #if DEBUG
            NetworkDiagnostics.logCareerLoadFailure(path: "/users/me", error: error)
            #endif
            throw error
        }
    }

    private func loadCollection<Element: Decodable & Equatable & Sendable>(
        _ type: [Element].Type,
        path: String
    ) async throws -> [Element] {
        let data: Data
        do {
            data = try await sessionService.sendAuthenticated(
                NetworkRequest(
                    path: path,
                    headers: ["Accept": "application/json"]
                )
            )
        } catch {
            #if DEBUG
            NetworkDiagnostics.logCareerLoadFailure(path: path, error: error)
            #endif
            throw error
        }

        let decoder = APIJSONCoder.makeDecoder()

        do {
            let decoded = try decoder.decode([Element].self, from: data)
            #if DEBUG
            NetworkDiagnostics.logCareerDecodeSuccess(
                path: path,
                shape: "array",
                itemCount: decoded.count
            )
            #endif
            return decoded
        } catch let arrayDecodeError {
            do {
                let decoded = try decoder.decode(CareerCollectionEnvelopeDTO<Element>.self, from: data).items
                #if DEBUG
                NetworkDiagnostics.logCareerDecodeSuccess(
                    path: path,
                    shape: "envelope",
                    itemCount: decoded.count
                )
                #endif
                return decoded
            } catch let envelopeDecodeError {
                #if DEBUG
                NetworkDiagnostics.logCareerDecodeFailure(
                    path: path,
                    primaryError: arrayDecodeError,
                    envelopeError: envelopeDecodeError
                )
                #endif
                throw envelopeDecodeError
            }
        }
    }
}
