import Foundation

// PATCH date fields are deliberate values, including explicit null for removal.
// Optional metadata uses explicit edits; dates retain their established null semantics.
extension CareerEmploymentUpdateRequestDTO {
    private nonisolated enum DatePatchKeys: String, CodingKey {
        case subjectFullName, subjectEmail, employerLegalName, employerTradeName, jobTitle, employmentType, startDate, endDate, workLocationCountry, workLocationRegion, workLocationCity, workArrangement
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: DatePatchKeys.self)
        try values.encodeIfPresent(subjectFullName, forKey: .subjectFullName)
        try values.encodeIfPresent(subjectEmail, forKey: .subjectEmail)
        try values.encodeIfPresent(employerLegalName, forKey: .employerLegalName)
        try values.encodeChange(metadataChanges["employerTradeName"] ?? .supplied(employerTradeName), forKey: .employerTradeName)
        try values.encodeIfPresent(jobTitle, forKey: .jobTitle)
        try values.encodeIfPresent(employmentType, forKey: .employmentType)
        try values.encode(startDate, forKey: .startDate)
        try values.encode(endDate, forKey: .endDate)
        if updatesCountry { try values.encode(workLocationCountry, forKey: .workLocationCountry) }
        else { try values.encodeIfPresent(workLocationCountry, forKey: .workLocationCountry) }
        if updatesRegion { try values.encode(workLocationRegion, forKey: .workLocationRegion) }
        else { try values.encodeIfPresent(workLocationRegion, forKey: .workLocationRegion) }
        if updatesCity { try values.encode(workLocationCity, forKey: .workLocationCity) }
        else { try values.encodeIfPresent(workLocationCity, forKey: .workLocationCity) }
        try values.encodeIfPresent(workArrangement, forKey: .workArrangement)
    }
}

extension CareerEducationUpdateRequestDTO {
    private nonisolated enum DatePatchKeys: String, CodingKey {
        case institutionName, institutionCatalogueID, institutionCatalogueVersion, degree, fieldOfStudy, educationLevel, grade, startDate, startDatePrecision, endDate, endDatePrecision, isCurrentlyStudying
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: DatePatchKeys.self)
        try values.encodeIfPresent(institutionName, forKey: .institutionName)
        try values.encodeChange(metadataChanges["institutionCatalogueID"] ?? .unchanged, forKey: .institutionCatalogueID)
        try values.encodeChange(metadataChanges["institutionCatalogueVersion"] ?? .unchanged, forKey: .institutionCatalogueVersion)
        try values.encodeIfPresent(degree, forKey: .degree)
        try values.encodeChange(metadataChanges["fieldOfStudy"] ?? .supplied(fieldOfStudy), forKey: .fieldOfStudy)
        try values.encodeIfPresent(educationLevel, forKey: .educationLevel)
        try values.encodeChange(metadataChanges["grade"] ?? .supplied(grade), forKey: .grade)
        try values.encode(startDate, forKey: .startDate)
        try values.encode(startDatePrecision, forKey: .startDatePrecision)
        try values.encode(endDate, forKey: .endDate)
        try values.encode(endDatePrecision, forKey: .endDatePrecision)
        try values.encodeIfPresent(isCurrentlyStudying, forKey: .isCurrentlyStudying)
    }
}

extension CareerCertificationUpdateRequestDTO {
    private nonisolated enum DatePatchKeys: String, CodingKey {
        case title, issuingOrganization, issuedDate, expiryDate, doesNotExpire, credentialID, credentialURL
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: DatePatchKeys.self)
        try values.encodeIfPresent(title, forKey: .title)
        try values.encodeIfPresent(issuingOrganization, forKey: .issuingOrganization)
        try values.encode(issuedDate, forKey: .issuedDate)
        try values.encode(expiryDate, forKey: .expiryDate)
        try values.encodeIfPresent(doesNotExpire, forKey: .doesNotExpire)
        try values.encodeChange(metadataChanges["credentialID"] ?? .supplied(credentialID), forKey: .credentialID)
        try values.encodeChange(metadataChanges["credentialURL"] ?? .supplied(credentialURL), forKey: .credentialURL)
    }
}

extension CareerProjectUpdateRequestDTO {
    private nonisolated enum DatePatchKeys: String, CodingKey {
        case title, role, description, startDate, endDate, isOngoing, projectURL, repositoryURL, organizationName
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: DatePatchKeys.self)
        try values.encodeIfPresent(title, forKey: .title)
        try values.encodeChange(metadataChanges["role"] ?? .supplied(role), forKey: .role)
        try values.encodeChange(metadataChanges["description"] ?? .supplied(description), forKey: .description)
        try values.encode(startDate, forKey: .startDate)
        try values.encode(endDate, forKey: .endDate)
        try values.encodeIfPresent(isOngoing, forKey: .isOngoing)
        try values.encodeChange(metadataChanges["projectURL"] ?? .supplied(projectURL), forKey: .projectURL)
        try values.encodeChange(metadataChanges["repositoryURL"] ?? .supplied(repositoryURL), forKey: .repositoryURL)
        try values.encodeChange(metadataChanges["organizationName"] ?? .supplied(organizationName), forKey: .organizationName)
    }
}

nonisolated struct CareerCollectionEnvelopeDTO<Element: Decodable & Equatable & Sendable>: Decodable, Equatable, Sendable {
    let items: [Element]

    nonisolated init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let items = try? container.decode([Element].self) {
            self.items = items
            return
        }

        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        let itemsKey = DynamicCodingKey("items")
        if let decoded = try container.decodeIfPresent([Element].self, forKey: itemsKey) {
            items = decoded
            return
        }

        throw DecodingError.keyNotFound(
            itemsKey,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing items collection.")
        )
    }
}

nonisolated struct CareerEmploymentDTO: Decodable, Equatable, Sendable {
    let id: String
    let subjectFullName: String?
    let subjectEmail: String?
    let employerLegalName: String?
    let employerTradeName: String?
    let jobTitle: String
    let employmentType: String?
    let startDate: Date?
    let endDate: Date?
    let workLocationCity: String?
    let workLocationCountry: String?
    let workLocationRegion: String?
    let workArrangement: String?
    let verificationMethod: String?
    let verificationStatus: String

    var companyDisplayName: String {
        employerTradeName?.nonEmpty ?? employerLegalName?.nonEmpty ?? "Company not added yet"
    }

    var currentlyWorking: Bool {
        endDate == nil
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = try container.decodeRequiredString(forKeys: ["id"], debugName: "employment id")
        subjectFullName = try container.decodeFirstPresentString(forKeys: ["subject_full_name"])
        subjectEmail = try container.decodeFirstPresentString(forKeys: ["subject_email"])
        employerLegalName = try container.decodeFirstPresentString(
            forKeys: ["employer_legal_name", "employer_name", "company_name", "company", "organization_name"]
        )
        employerTradeName = try container.decodeFirstPresentString(
            forKeys: ["employer_trade_name", "company_display_name", "display_name"]
        )
        jobTitle = try container.decodeRequiredString(
            forKeys: ["job_title", "role_title", "title"],
            debugName: "employment job title"
        )
        employmentType = try container.decodeFirstPresentString(forKeys: ["employment_type"])
        startDate = try container.decodeFirstPresentDate(forKeys: ["start_date"])
        endDate = try container.decodeFirstPresentDate(forKeys: ["end_date"])
        workLocationCity = try container.decodeFirstPresentString(forKeys: ["work_location_city"])
        workLocationCountry = try container.decodeFirstPresentString(forKeys: ["work_location_country"])
        workLocationRegion = try container.decodeFirstPresentString(forKeys: ["work_location_region"])
        workArrangement = try container.decodeFirstPresentString(forKeys: ["work_arrangement"])
        verificationMethod = try container.decodeFirstPresentString(
            forKeys: ["verification_method"]
        )
        verificationStatus = try container.decodeFirstPresentString(
            forKeys: ["verification_status", "status"]
        ) ?? "draft"
    }
}

nonisolated struct CareerEducationDTO: Decodable, Equatable, Sendable {
    let institutionCatalogueID: String?
    let institutionCatalogueVersion: String?
    let id: String
    let userID: String?
    let institutionName: String
    let degree: String?
    let fieldOfStudy: String?
    let educationLevel: String?
    let grade: String?
    let startDate: Date?
    let startDatePrecision: String?
    let endDate: Date?
    let endDatePrecision: String?
    let isCurrentlyStudying: Bool
    let verificationStatus: String

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = try container.decodeRequiredString(forKeys: ["id"], debugName: "education id")
        userID = try container.decodeFirstPresentString(forKeys: ["user_id"])
        institutionCatalogueID = try container.decodeFirstPresentString(forKeys: ["institution_catalogue_id"])
        institutionCatalogueVersion = try container.decodeFirstPresentString(forKeys: ["institution_catalogue_version"])
        institutionName = try container.decodeFirstPresentString(
            forKeys: ["institution_name", "school_name", "organization_name"]
        ) ?? "Institution not added yet"
        degree = try container.decodeFirstPresentString(forKeys: ["degree"])
        fieldOfStudy = try container.decodeFirstPresentString(forKeys: ["field_of_study"])
        educationLevel = try container.decodeFirstPresentString(forKeys: ["education_level"])
        grade = try container.decodeFirstPresentString(forKeys: ["grade"])
        startDate = try container.decodeFirstPresentDate(forKeys: ["start_date"])
        startDatePrecision = try container.decodeFirstPresentString(forKeys: ["start_date_precision"])
        endDate = try container.decodeFirstPresentDate(forKeys: ["end_date"])
        endDatePrecision = try container.decodeFirstPresentString(forKeys: ["end_date_precision"])
        isCurrentlyStudying = try container.decodeFirstPresentBool(
            forKeys: ["is_currently_studying"],
            defaultValue: false
        )
        verificationStatus = try container.decodeFirstPresentString(
            forKeys: ["verification_status", "status"]
        ) ?? "draft"
    }
}

nonisolated struct CareerCertificationDTO: Decodable, Equatable, Sendable {
    let id: String
    let title: String
    let issuingOrganization: String?
    let issuedDate: Date?
    let expiryDate: Date?
    let doesNotExpire: Bool
    let credentialID: String?
    let credentialURL: URL?
    let originalFilename: String?
    let contentType: String?
    let byteSize: Int?
    let verificationStatus: String

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = try container.decodeRequiredString(forKeys: ["id"], debugName: "certification id")
        title = try container.decodeRequiredString(forKeys: ["title"], debugName: "certification title")
        issuingOrganization = try container.decodeFirstPresentString(forKeys: ["issuing_organization"])
        issuedDate = try container.decodeFirstPresentDate(forKeys: ["issued_date"])
        expiryDate = try container.decodeFirstPresentDate(forKeys: ["expiry_date"])
        doesNotExpire = try container.decodeFirstPresentBool(
            forKeys: ["does_not_expire"],
            defaultValue: false
        )
        credentialID = try container.decodeFirstPresentString(forKeys: ["credential_id"])
        credentialURL = try container.decodeFirstPresentURL(forKeys: ["credential_url"])
        originalFilename = try container.decodeFirstPresentString(forKeys: ["original_filename"])
        contentType = try container.decodeFirstPresentString(forKeys: ["content_type"])
        byteSize = try container.decodeFirstPresentInt(forKeys: ["byte_size"])
        verificationStatus = try container.decodeFirstPresentString(
            forKeys: ["verification_status", "status"]
        ) ?? "draft"
    }
}

nonisolated struct CareerProjectDTO: Decodable, Equatable, Sendable {
    let id: String
    let title: String
    let role: String?
    let description: String?
    let startDate: Date?
    let endDate: Date?
    let isOngoing: Bool
    let projectURL: URL?
    let repositoryURL: URL?
    let organizationName: String?
    let verificationStatus: String

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = try container.decodeRequiredString(forKeys: ["id"], debugName: "project id")
        title = try container.decodeRequiredString(forKeys: ["title"], debugName: "project title")
        role = try container.decodeFirstPresentString(forKeys: ["role"])
        description = try container.decodeFirstPresentString(forKeys: ["description"])
        startDate = try container.decodeFirstPresentDate(forKeys: ["start_date"])
        endDate = try container.decodeFirstPresentDate(forKeys: ["end_date"])
        isOngoing = try container.decodeFirstPresentBool(forKeys: ["is_ongoing"], defaultValue: false)
        projectURL = try container.decodeFirstPresentURL(forKeys: ["project_url"])
        repositoryURL = try container.decodeFirstPresentURL(forKeys: ["repository_url"])
        organizationName = try container.decodeFirstPresentString(forKeys: ["organization_name"])
        verificationStatus = try container.decodeFirstPresentString(
            forKeys: ["verification_status", "status"]
        ) ?? "draft"
    }
}

nonisolated struct CareerSkillDTO: Decodable, Equatable, Sendable {
    let id: String
    let userID: String?
    let name: String
    let verificationStatus: String

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        name = try container.decodeRequiredString(
            forKeys: ["name", "skill_name", "title"],
            debugName: "skill name"
        )
        id = try container.decodeFirstPresentString(forKeys: ["id", "public_id"]) ?? name
        userID = try container.decodeFirstPresentString(forKeys: ["user_id"])
        verificationStatus = try container.decodeFirstPresentString(
            forKeys: ["verification_status", "status"]
        ) ?? "draft"
    }
}

nonisolated struct CareerEmploymentCreateRequestDTO: Encodable, Equatable, Sendable {
    let subjectFullName: String
    let subjectEmail: String?
    let employerLegalName: String
    let employerTradeName: String?
    let jobTitle: String
    let employmentType: String
    let verificationMethod: String
    let startDate: String
    let endDate: String?
    let workLocationCountry: String?
    let workLocationRegion: String?
    var workLocationCity: String? = nil
    var workArrangement: String? = nil
}

nonisolated struct CareerEmploymentUpdateRequestDTO: Encodable, Equatable, Sendable {
    let subjectFullName: String?
    let subjectEmail: String?
    let employerLegalName: String?
    let employerTradeName: String?
    let jobTitle: String?
    let employmentType: String?
    let startDate: String?
    let endDate: String?
    let workLocationCountry: String?
    let workLocationRegion: String?
    var workLocationCity: String? = nil
    var workArrangement: String? = nil
    // Distinguish deliberate optional-location clearing from preserving an unknown legacy value.
    var updatesCountry = false
    var updatesRegion = false
    var updatesCity = false
    var metadataChanges: [String: OptionalFieldChange<String>] = [:]
}

nonisolated struct CareerEducationCreateRequestDTO: Encodable, Equatable, Sendable {
    let institutionName: String
    let degree: String
    let fieldOfStudy: String?
    let educationLevel: String
    let grade: String?
    let startDate: String
    let startDatePrecision: String?
    let endDate: String?
    let endDatePrecision: String?
    let isCurrentlyStudying: Bool
    var institutionCatalogueID: String? = nil
    var institutionCatalogueVersion: String? = nil

    private enum CodingKeys: String, CodingKey {
        case institutionName, degree, fieldOfStudy, educationLevel, grade, startDate, startDatePrecision, endDate, endDatePrecision, isCurrentlyStudying, institutionCatalogueID, institutionCatalogueVersion
    }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(institutionName, forKey: .institutionName)
        try values.encode(degree, forKey: .degree)
        try values.encodeIfPresent(fieldOfStudy, forKey: .fieldOfStudy)
        try values.encode(educationLevel, forKey: .educationLevel)
        try values.encodeIfPresent(grade, forKey: .grade)
        try values.encode(startDate, forKey: .startDate)
        try values.encodeIfPresent(startDatePrecision, forKey: .startDatePrecision)
        try values.encodeIfPresent(endDate, forKey: .endDate)
        try values.encodeIfPresent(endDatePrecision, forKey: .endDatePrecision)
        try values.encode(isCurrentlyStudying, forKey: .isCurrentlyStudying)
        try values.encode(institutionCatalogueID, forKey: .institutionCatalogueID)
        try values.encode(institutionCatalogueVersion, forKey: .institutionCatalogueVersion)
    }
}

nonisolated struct CareerEducationUpdateRequestDTO: Encodable, Equatable, Sendable {
    let institutionName: String?
    let degree: String?
    let fieldOfStudy: String?
    let educationLevel: String?
    let grade: String?
    let startDate: String?
    let startDatePrecision: String?
    let endDate: String?
    let endDatePrecision: String?
    let isCurrentlyStudying: Bool?
    var metadataChanges: [String: OptionalFieldChange<String>] = [:]
}

nonisolated struct CareerCertificationCreateRequestDTO: Encodable, Equatable, Sendable {
    let title: String
    let issuingOrganization: String
    let issuedDate: String
    let expiryDate: String?
    let doesNotExpire: Bool
    let credentialID: String?
    let credentialURL: String?
}

nonisolated struct CareerCertificationUpdateRequestDTO: Encodable, Equatable, Sendable {
    let title: String?
    let issuingOrganization: String?
    let issuedDate: String?
    let expiryDate: String?
    let doesNotExpire: Bool?
    let credentialID: String?
    let credentialURL: String?
    var metadataChanges: [String: OptionalFieldChange<String>] = [:]
}

nonisolated struct CareerCertificationUploadIntentRequestDTO: Encodable, Equatable, Sendable {
    let title: String
    let issuingOrganization: String
    let issuedDate: String?
    let expiryDate: String?
    let doesNotExpire: Bool
    let credentialID: String?
    let credentialURL: String?
    let originalFilename: String
    let contentType: String
    let byteSize: Int
}

nonisolated struct CareerCertificationUploadIntentResponseDTO: Decodable, Equatable, Sendable {
    let certificationId: String
    let uploadUrl: URL
}

nonisolated struct CareerCertificationCompleteUploadRequestDTO: Encodable, Equatable, Sendable {
    let checksumSHA256: String
}

nonisolated struct CareerProjectCreateRequestDTO: Encodable, Equatable, Sendable {
    let title: String
    let role: String?
    let description: String?
    let startDate: String?
    let endDate: String?
    let isOngoing: Bool
    let projectURL: String?
    let repositoryURL: String?
    let organizationName: String?
}

nonisolated struct CareerProjectUpdateRequestDTO: Encodable, Equatable, Sendable {
    let title: String?
    let role: String?
    let description: String?
    let startDate: String?
    let endDate: String?
    let isOngoing: Bool?
    let projectURL: String?
    let repositoryURL: String?
    let organizationName: String?
    var metadataChanges: [String: OptionalFieldChange<String>] = [:]
}

nonisolated struct CareerSkillCreateRequestDTO: Encodable, Equatable, Sendable {
    let name: String
}

private struct DynamicCodingKey: CodingKey, Hashable {
    let stringValue: String
    let intValue: Int?

    nonisolated init(_ string: String) {
        stringValue = string
        intValue = nil
    }

    nonisolated init?(stringValue: String) {
        self.init(stringValue)
    }

    nonisolated init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

private extension KeyedDecodingContainer where Key == DynamicCodingKey {
    nonisolated func candidateKeys(for rawKey: String) -> [DynamicCodingKey] {
        let camelCaseKey = rawKey
            .split(separator: "_")
            .enumerated()
            .map { index, component in
                index == 0 ? component.lowercased() : component.capitalized
            }
            .joined()

        if camelCaseKey == rawKey {
            return [DynamicCodingKey(rawKey)]
        }

        return [DynamicCodingKey(rawKey), DynamicCodingKey(camelCaseKey)]
    }

    nonisolated func decodeRequiredString(
        forKeys keys: [String],
        debugName: String
    ) throws -> String {
        if let value = try decodeFirstPresentString(forKeys: keys) {
            return value
        }

        throw DecodingError.keyNotFound(
            DynamicCodingKey(keys.first ?? debugName),
            DecodingError.Context(codingPath: codingPath, debugDescription: "Missing \(debugName).")
        )
    }

    nonisolated func decodeFirstPresentString(forKeys keys: [String]) throws -> String? {
        for rawKey in keys {
            for key in candidateKeys(for: rawKey) {
                if let value = try decodeIfPresent(String.self, forKey: key)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !value.isEmpty {
                    return value
                }
            }
        }

        return nil
    }

    nonisolated func decodeFirstPresentBool(
        forKeys keys: [String],
        defaultValue: Bool
    ) throws -> Bool {
        for rawKey in keys {
            for key in candidateKeys(for: rawKey) {
                if let value = try decodeIfPresent(Bool.self, forKey: key) {
                    return value
                }

                if let stringValue = try decodeIfPresent(String.self, forKey: key)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased() {
                    switch stringValue {
                    case "true", "yes", "1":
                        return true
                    case "false", "no", "0":
                        return false
                    default:
                        break
                    }
                }
            }
        }

        return defaultValue
    }

    nonisolated func decodeFirstPresentDate(forKeys keys: [String]) throws -> Date? {
        for rawKey in keys {
            for key in candidateKeys(for: rawKey) {
                if let value = try decodeIfPresent(Date.self, forKey: key) {
                    return value
                }
            }
        }

        return nil
    }

    nonisolated func decodeFirstPresentInt(forKeys keys: [String]) throws -> Int? {
        for rawKey in keys {
            for key in candidateKeys(for: rawKey) {
                if let value = try decodeIfPresent(Int.self, forKey: key) {
                    return value
                }

                if let stringValue = try decodeIfPresent(String.self, forKey: key)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   let value = Int(stringValue) {
                    return value
                }
            }
        }

        return nil
    }

    nonisolated func decodeFirstPresentURL(forKeys keys: [String]) throws -> URL? {
        for rawKey in keys {
            for key in candidateKeys(for: rawKey) {
                if let value = try decodeIfPresent(URL.self, forKey: key) {
                    return value
                }

                if let stringValue = try decodeIfPresent(String.self, forKey: key)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   let value = URL(string: stringValue),
                   !stringValue.isEmpty {
                    return value
                }
            }
        }

        return nil
    }
}

private extension String {
    nonisolated
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
