import Foundation

nonisolated enum APIErrorCode: String, Decodable, Equatable, Sendable {
    case badRequest = "bad_request"
    case unauthorized
    case forbidden
    case notFound = "not_found"
    case conflict
    case validationError = "validation_error"
    case rateLimited = "rate_limited"
    case internalError = "internal_error"
    case serviceUnavailable = "service_unavailable"
}

nonisolated struct APIValidationErrorDetail: Decodable, Equatable, Sendable {
    let location: [LocationComponent]
    let message: String
    let errorType: String

    nonisolated var fieldName: String? {
        location
            .reversed()
            .compactMap(\.stringValue)
            .first { !Self.reservedLocationComponents.contains($0) }
    }

    private nonisolated static let reservedLocationComponents: Set<String> = [
        "body",
        "query",
        "path",
        "header",
        "cookie"
    ]
}

nonisolated enum LocationComponent: Decodable, Equatable, Sendable {
    case string(String)
    case index(Int)

    nonisolated var stringValue: String? {
        switch self {
        case .string(let value):
            value
        case .index:
            nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let index = try? container.decode(Int.self) {
            self = .index(index)
            return
        }

        self = .string(try container.decode(String.self))
    }
}

nonisolated struct APIError: Error, Equatable, LocalizedError, Sendable {
    let statusCode: Int
    let code: APIErrorCode
    let message: String
    let fieldErrors: [String: [String]]
    let globalErrors: [String]
    let validationDetails: [APIValidationErrorDetail]

    var errorDescription: String? {
        message
    }

    static func decode(from data: Data, statusCode: Int) -> APIError? {
        guard !data.isEmpty else {
            guard let code = APIError.defaultCode(for: statusCode) else {
                return nil
            }

            return APIError(
                statusCode: statusCode,
                code: code,
                message: code.fallbackMessage,
                fieldErrors: [:],
                globalErrors: [],
                validationDetails: []
            )
        }

        do {
            let envelope = try APIJSONCoder.makeDecoder().decode(APIErrorEnvelope.self, from: data)
            guard
                let decodedCode = envelope.resolvedCode ?? APIError.defaultCode(for: statusCode)
            else {
                return nil
            }

            let detailGroups = resolveValidationDetails(envelope.resolvedValidationDetails)
            return APIError(
                statusCode: statusCode,
                code: decodedCode,
                message: envelope.resolvedMessage ?? decodedCode.fallbackMessage,
                fieldErrors: detailGroups.fieldErrors,
                globalErrors: detailGroups.globalErrors,
                validationDetails: envelope.resolvedValidationDetails
            )
        } catch {
            guard let code = APIError.defaultCode(for: statusCode) else {
                return nil
            }

            return APIError(
                statusCode: statusCode,
                code: code,
                message: code.fallbackMessage,
                fieldErrors: [:],
                globalErrors: [],
                validationDetails: []
            )
        }
    }

    private static func resolveValidationDetails(
        _ details: [APIValidationErrorDetail]
    ) -> (fieldErrors: [String: [String]], globalErrors: [String]) {
        var fieldErrors: [String: [String]] = [:]
        var globalErrors: [String] = []

        for detail in details {
            if let fieldName = detail.fieldName {
                fieldErrors[fieldName, default: []].append(detail.message)
            } else {
                globalErrors.append(detail.message)
            }
        }

        return (fieldErrors, globalErrors)
    }

    private static func defaultCode(for statusCode: Int) -> APIErrorCode? {
        switch statusCode {
        case 400: .badRequest
        case 401: .unauthorized
        case 403: .forbidden
        case 404: .notFound
        case 409: .conflict
        case 422: .validationError
        case 429: .rateLimited
        case 500: .internalError
        case 503: .serviceUnavailable
        default: nil
        }
    }
}

private nonisolated struct APIErrorEnvelope: Decodable {
    let code: APIErrorCode?
    let message: String?
    let error: NestedError?
    let details: [APIValidationErrorDetail]?
    let errors: [String: FieldMessages]?

    var resolvedCode: APIErrorCode? {
        code ?? error?.code
    }

    var resolvedMessage: String? {
        message ?? error?.message
    }

    var resolvedValidationDetails: [APIValidationErrorDetail] {
        if let nestedDetails = error?.details {
            return nestedDetails
        }

        return details ?? []
    }

    nonisolated struct NestedError: Decodable {
        let code: APIErrorCode?
        let message: String?
        let details: [APIValidationErrorDetail]?
    }
}

private nonisolated struct FieldMessages: Decodable {
    let messages: [String]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(String.self) {
            messages = [value]
            return
        }

        if let values = try? container.decode([String].self) {
            messages = values
            return
        }

        messages = []
    }
}

private extension APIErrorCode {
    nonisolated var fallbackMessage: String {
        switch self {
        case .badRequest:
            "The request could not be accepted."
        case .unauthorized:
            "Your session is no longer valid."
        case .forbidden:
            "You do not have permission to perform this action."
        case .notFound:
            "The requested resource could not be found."
        case .conflict:
            "This action conflicts with the current account state."
        case .validationError:
            "Please review the highlighted information and try again."
        case .rateLimited:
            "Too many attempts. Please try again shortly."
        case .internalError:
            "Kairo ran into an internal error. Please try again."
        case .serviceUnavailable:
            "Kairo is temporarily unavailable. Please try again."
        }
    }
}
