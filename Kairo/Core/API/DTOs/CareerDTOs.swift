import Foundation

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
    let workLocationCountry: String?
    let workLocationRegion: String?
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
        workLocationCountry = try container.decodeFirstPresentString(forKeys: ["work_location_country"])
        workLocationRegion = try container.decodeFirstPresentString(forKeys: ["work_location_region"])
        verificationMethod = try container.decodeFirstPresentString(
            forKeys: ["verification_method"]
        )
        verificationStatus = try container.decodeFirstPresentString(
            forKeys: ["verification_status", "status"]
        ) ?? "draft"
    }
}

nonisolated struct CareerEducationDTO: Decodable, Equatable, Sendable {
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
    let workLocationCountry: String
    let workLocationRegion: String?
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
