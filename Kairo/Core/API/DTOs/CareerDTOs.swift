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
    let employerLegalName: String
    let employerTradeName: String?
    let jobTitle: String
    let employmentType: String?
    let startDate: Date?
    let endDate: Date?
    let workLocationCountry: String?
    let workLocationRegion: String?
    let verificationStatus: String

    var companyDisplayName: String {
        employerTradeName?.nonEmpty ?? employerLegalName
    }

    var currentlyWorking: Bool {
        endDate == nil
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = try container.decodeRequiredString(forKeys: ["id"], debugName: "employment id")
        employerLegalName = try container.decodeRequiredString(
            forKeys: ["employer_legal_name"],
            debugName: "employment employer legal name"
        )
        employerTradeName = try container.decodeFirstPresentString(forKeys: ["employer_trade_name"])
        jobTitle = try container.decodeRequiredString(forKeys: ["job_title"], debugName: "employment job title")
        employmentType = try container.decodeFirstPresentString(forKeys: ["employment_type"])
        startDate = try container.decodeFirstPresentDate(forKeys: ["start_date"])
        endDate = try container.decodeFirstPresentDate(forKeys: ["end_date"])
        workLocationCountry = try container.decodeFirstPresentString(forKeys: ["work_location_country"])
        workLocationRegion = try container.decodeFirstPresentString(forKeys: ["work_location_region"])
        verificationStatus = try container.decodeRequiredString(
            forKeys: ["verification_status"],
            debugName: "employment verification status"
        )
    }
}

nonisolated struct CareerEducationDTO: Decodable, Equatable, Sendable {
    let id: String
    let institutionName: String
    let degree: String?
    let fieldOfStudy: String?
    let educationLevel: String?
    let startDate: Date?
    let startDatePrecision: String?
    let endDate: Date?
    let endDatePrecision: String?
    let isCurrentlyStudying: Bool
    let verificationStatus: String

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = try container.decodeRequiredString(forKeys: ["id"], debugName: "education id")
        institutionName = try container.decodeRequiredString(
            forKeys: ["institution_name"],
            debugName: "education institution name"
        )
        degree = try container.decodeFirstPresentString(forKeys: ["degree"])
        fieldOfStudy = try container.decodeFirstPresentString(forKeys: ["field_of_study"])
        educationLevel = try container.decodeFirstPresentString(forKeys: ["education_level"])
        startDate = try container.decodeFirstPresentDate(forKeys: ["start_date"])
        startDatePrecision = try container.decodeFirstPresentString(forKeys: ["start_date_precision"])
        endDate = try container.decodeFirstPresentDate(forKeys: ["end_date"])
        endDatePrecision = try container.decodeFirstPresentString(forKeys: ["end_date_precision"])
        isCurrentlyStudying = try container.decodeFirstPresentBool(
            forKeys: ["is_currently_studying"],
            defaultValue: false
        )
        verificationStatus = try container.decodeRequiredString(
            forKeys: ["verification_status"],
            debugName: "education verification status"
        )
    }
}

nonisolated struct CareerCertificationDTO: Decodable, Equatable, Sendable {
    let id: String
    let title: String
    let issuingOrganization: String?
    let issuedDate: Date?
    let verificationStatus: String

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = try container.decodeRequiredString(forKeys: ["id"], debugName: "certification id")
        title = try container.decodeRequiredString(forKeys: ["title"], debugName: "certification title")
        issuingOrganization = try container.decodeFirstPresentString(forKeys: ["issuing_organization"])
        issuedDate = try container.decodeFirstPresentDate(forKeys: ["issued_date"])
        verificationStatus = try container.decodeRequiredString(
            forKeys: ["verification_status"],
            debugName: "certification verification status"
        )
    }
}

nonisolated struct CareerProjectDTO: Decodable, Equatable, Sendable {
    let id: String
    let title: String
    let role: String?
    let startDate: Date?
    let endDate: Date?
    let isOngoing: Bool
    let projectURL: URL?
    let repositoryURL: URL?
    let verificationStatus: String

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = try container.decodeRequiredString(forKeys: ["id"], debugName: "project id")
        title = try container.decodeRequiredString(forKeys: ["title"], debugName: "project title")
        role = try container.decodeFirstPresentString(forKeys: ["role"])
        startDate = try container.decodeFirstPresentDate(forKeys: ["start_date"])
        endDate = try container.decodeFirstPresentDate(forKeys: ["end_date"])
        isOngoing = try container.decodeFirstPresentBool(forKeys: ["is_ongoing"], defaultValue: false)
        projectURL = try container.decodeFirstPresentURL(forKeys: ["project_url"])
        repositoryURL = try container.decodeFirstPresentURL(forKeys: ["repository_url"])
        verificationStatus = try container.decodeRequiredString(
            forKeys: ["verification_status"],
            debugName: "project verification status"
        )
    }
}

nonisolated struct CareerSkillDTO: Decodable, Equatable, Sendable {
    let id: String
    let name: String
    let verificationStatus: String

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = try container.decodeRequiredString(forKeys: ["id"], debugName: "skill id")
        name = try container.decodeRequiredString(forKeys: ["name"], debugName: "skill name")
        verificationStatus = try container.decodeRequiredString(
            forKeys: ["verification_status"],
            debugName: "skill verification status"
        )
    }
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
            let key = DynamicCodingKey(rawKey)
            if let value = try decodeIfPresent(String.self, forKey: key)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                return value
            }
        }

        return nil
    }

    nonisolated func decodeFirstPresentBool(
        forKeys keys: [String],
        defaultValue: Bool
    ) throws -> Bool {
        for rawKey in keys {
            let key = DynamicCodingKey(rawKey)
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

        return defaultValue
    }

    nonisolated func decodeFirstPresentDate(forKeys keys: [String]) throws -> Date? {
        for rawKey in keys {
            let key = DynamicCodingKey(rawKey)
            if let value = try decodeIfPresent(Date.self, forKey: key) {
                return value
            }
        }

        return nil
    }

    nonisolated func decodeFirstPresentURL(forKeys keys: [String]) throws -> URL? {
        for rawKey in keys {
            let key = DynamicCodingKey(rawKey)
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

        return nil
    }
}

private extension String {
    nonisolated
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
