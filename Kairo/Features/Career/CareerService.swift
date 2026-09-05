import Foundation

protocol CareerOverviewServiceProtocol: Sendable {
    func loadOverview() async throws -> CareerOverview
    func loadEmployment(id: String) async throws -> CareerEmploymentRecord
    func loadEducation(id: String) async throws -> CareerEducationRecord
    func loadCertification(id: String) async throws -> CareerCertificationRecord
    func loadProject(id: String) async throws -> CareerProjectRecord
    func createEmployment(_ request: CareerEmploymentCreateRequestDTO) async throws -> CareerOverview
    func updateEmployment(id: String, request: CareerEmploymentUpdateRequestDTO) async throws -> CareerOverview
    func deleteEmployment(id: String) async throws -> CareerOverview
    func createEducation(_ request: CareerEducationCreateRequestDTO) async throws -> CareerOverview
    func updateEducation(id: String, request: CareerEducationUpdateRequestDTO) async throws -> CareerOverview
    func deleteEducation(id: String) async throws -> CareerOverview
    func createCertification(_ request: CareerCertificationCreateRequestDTO) async throws -> CareerOverview
    func updateCertification(id: String, request: CareerCertificationUpdateRequestDTO) async throws -> CareerOverview
    func deleteCertification(id: String) async throws -> CareerOverview
    func createProject(_ request: CareerProjectCreateRequestDTO) async throws -> CareerOverview
    func updateProject(id: String, request: CareerProjectUpdateRequestDTO) async throws -> CareerOverview
    func deleteProject(id: String) async throws -> CareerOverview
    func createSkill(_ request: CareerSkillCreateRequestDTO) async throws -> CareerOverview
    func deleteSkill(id: String) async throws -> CareerOverview
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

    func loadEmployment(id: String) async throws -> CareerEmploymentRecord {
        try await loadRecord(
            path: "/employments/\(id)",
            as: CareerEmploymentDTO.self,
            transform: CareerEmploymentRecord.init(dto:)
        )
    }

    func loadEducation(id: String) async throws -> CareerEducationRecord {
        try await loadRecord(
            path: "/educations/\(id)",
            as: CareerEducationDTO.self,
            transform: CareerEducationRecord.init(dto:)
        )
    }

    func loadCertification(id: String) async throws -> CareerCertificationRecord {
        try await loadRecord(
            path: "/certifications/\(id)",
            as: CareerCertificationDTO.self,
            transform: CareerCertificationRecord.init(dto:)
        )
    }

    func loadProject(id: String) async throws -> CareerProjectRecord {
        try await loadRecord(
            path: "/projects/\(id)",
            as: CareerProjectDTO.self,
            transform: CareerProjectRecord.init(dto:)
        )
    }

    func createEmployment(_ request: CareerEmploymentCreateRequestDTO) async throws -> CareerOverview {
        try await mutate(
            path: "/employments/",
            method: .post,
            body: request,
            responseType: CareerEmploymentDTO.self
        )
    }

    func updateEmployment(
        id: String,
        request: CareerEmploymentUpdateRequestDTO
    ) async throws -> CareerOverview {
        try await mutate(
            path: "/employments/\(id)",
            method: .patch,
            body: request,
            responseType: CareerEmploymentDTO.self
        )
    }

    func deleteEmployment(id: String) async throws -> CareerOverview {
        try await deleteAndReload(path: "/employments/\(id)")
    }

    func createEducation(_ request: CareerEducationCreateRequestDTO) async throws -> CareerOverview {
        try await mutate(
            path: "/educations",
            method: .post,
            body: request,
            responseType: CareerEducationDTO.self
        )
    }

    func updateEducation(
        id: String,
        request: CareerEducationUpdateRequestDTO
    ) async throws -> CareerOverview {
        try await mutate(
            path: "/educations/\(id)",
            method: .patch,
            body: request,
            responseType: CareerEducationDTO.self
        )
    }

    func deleteEducation(id: String) async throws -> CareerOverview {
        try await deleteAndReload(path: "/educations/\(id)")
    }

    func createCertification(_ request: CareerCertificationCreateRequestDTO) async throws -> CareerOverview {
        try await mutate(
            path: "/certifications",
            method: .post,
            body: request,
            responseType: CareerCertificationDTO.self
        )
    }

    func updateCertification(
        id: String,
        request: CareerCertificationUpdateRequestDTO
    ) async throws -> CareerOverview {
        try await mutate(
            path: "/certifications/\(id)",
            method: .patch,
            body: request,
            responseType: CareerCertificationDTO.self
        )
    }

    func deleteCertification(id: String) async throws -> CareerOverview {
        try await deleteAndReload(path: "/certifications/\(id)")
    }

    func createProject(_ request: CareerProjectCreateRequestDTO) async throws -> CareerOverview {
        try await mutate(
            path: "/projects",
            method: .post,
            body: request,
            responseType: CareerProjectDTO.self
        )
    }

    func updateProject(
        id: String,
        request: CareerProjectUpdateRequestDTO
    ) async throws -> CareerOverview {
        try await mutate(
            path: "/projects/\(id)",
            method: .patch,
            body: request,
            responseType: CareerProjectDTO.self
        )
    }

    func deleteProject(id: String) async throws -> CareerOverview {
        try await deleteAndReload(path: "/projects/\(id)")
    }

    func createSkill(_ request: CareerSkillCreateRequestDTO) async throws -> CareerOverview {
        try await mutate(
            path: "/skills",
            method: .post,
            body: request,
            responseType: CareerSkillDTO.self
        )
    }

    func deleteSkill(id: String) async throws -> CareerOverview {
        try await deleteAndReload(path: "/skills/\(id)")
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

    private func loadRecord<DTO: Decodable, Domain>(
        path: String,
        as responseType: DTO.Type,
        transform: (DTO) -> Domain
    ) async throws -> Domain {
        let data = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: path,
                headers: ["Accept": "application/json"]
            )
        )
        return transform(try decoder.decode(responseType, from: data))
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

    private func mutate<Body: Encodable, Response: Decodable>(
        path: String,
        method: HTTPMethod,
        body: Body,
        responseType: Response.Type
    ) async throws -> CareerOverview {
        _ = try await sendJSONRequest(
            path: path,
            method: method,
            body: body,
            responseType: responseType
        )
        return try await loadOverview()
    }

    private func deleteAndReload(path: String) async throws -> CareerOverview {
        _ = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: path,
                method: .delete,
                headers: ["Accept": "application/json"]
            )
        )
        return try await loadOverview()
    }

    private func sendJSONRequest<Body: Encodable, Response: Decodable>(
        path: String,
        method: HTTPMethod,
        body: Body,
        responseType: Response.Type
    ) async throws -> Response {
        let data = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: path,
                method: method,
                headers: [
                    "Accept": "application/json",
                    "Content-Type": "application/json"
                ],
                body: try APIJSONCoder.makeEncoder().encode(body)
            )
        )
        return try decoder.decode(responseType, from: data)
    }

    private let decoder = APIJSONCoder.makeDecoder()
}
