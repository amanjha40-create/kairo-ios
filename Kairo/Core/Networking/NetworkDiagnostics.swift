import Foundation

#if DEBUG
enum NetworkDiagnostics {
    nonisolated static func logRequest(
        method: String,
        url: URL,
        requestID: String?,
        correlationID: String?
    ) {
        print(
            "[NetworkDiagnostics] request method=\(method) path=\(url.path) request_id=\(requestID ?? "-") correlation_id=\(correlationID ?? "-")"
        )
    }

    nonisolated static func logResponse(
        url: URL,
        statusCode: Int,
        contentType: String?,
        requestID: String?,
        correlationID: String?
    ) {
        print(
            "[NetworkDiagnostics] response path=\(url.path) status=\(statusCode) content_type=\(contentType ?? "-") request_id=\(requestID ?? "-") correlation_id=\(correlationID ?? "-")"
        )
    }

    nonisolated static func logTransportError(
        url: URL,
        requestID: String?,
        correlationID: String?,
        error: Error
    ) {
        let nsError = error as NSError
        print(
            "[NetworkDiagnostics] transport_error path=\(url.path) type=\(String(reflecting: type(of: error))) domain=\(nsError.domain) code=\(nsError.code) request_id=\(requestID ?? "-") correlation_id=\(correlationID ?? "-")"
        )
    }

    nonisolated static func logCareerDecodeSuccess(path: String, shape: String, itemCount: Int) {
        print(
            "[CareerDiagnostics] decode_success path=\(path) shape=\(shape) item_count=\(itemCount)"
        )
    }

    nonisolated static func logCareerDecodeFailure(
        path: String,
        primaryError: Error,
        envelopeError: Error?
    ) {
        var message = "[CareerDiagnostics] decode_failure path=\(path) primary_type=\(String(reflecting: type(of: primaryError)))"
        if let envelopeError {
            message += " envelope_type=\(String(reflecting: type(of: envelopeError)))"
        }
        print(message)
    }

    nonisolated static func logCareerLoadFailure(path: String, error: Error) {
        let nsError = error as NSError
        print(
            "[CareerDiagnostics] request_failure path=\(path) type=\(String(reflecting: type(of: error))) domain=\(nsError.domain) code=\(nsError.code)"
        )
    }

    nonisolated static func logPassportResponseShape(path: String, data: Data) {
        guard
            let rootObject = try? JSONSerialization.jsonObject(with: data),
            let root = rootObject as? [String: Any]
        else {
            print("[PassportDiagnostics] shape path=\(path) status=unreadable_json")
            return
        }

        let topLevelKeys = root.keys.sorted().joined(separator: ",")
        print("[PassportDiagnostics] shape path=\(path) top_level_keys=\(topLevelKeys)")

        if let profile = root["profile"] as? [String: Any] {
            print(
                "[PassportDiagnostics] section=profile keys=\(profile.keys.sorted().joined(separator: ",")) null_keys=\(nullKeyList(in: profile))"
            )
        } else {
            print("[PassportDiagnostics] section=profile kind=\(kindDescription(for: root["profile"]))")
        }

        if let trustScore = root["trust_score"] as? [String: Any] {
            print(
                "[PassportDiagnostics] section=trust_score keys=\(trustScore.keys.sorted().joined(separator: ",")) null_keys=\(nullKeyList(in: trustScore))"
            )
            if let breakdown = trustScore["breakdown"] as? [String: Any] {
                print(
                    "[PassportDiagnostics] section=trust_score.breakdown keys=\(breakdown.keys.sorted().joined(separator: ",")) null_keys=\(nullKeyList(in: breakdown))"
                )
            } else {
                print("[PassportDiagnostics] section=trust_score.breakdown kind=\(kindDescription(for: trustScore["breakdown"]))")
            }
        } else {
            print("[PassportDiagnostics] section=trust_score kind=\(kindDescription(for: root["trust_score"]))")
        }

        if let metadata = root["passport_metadata"] as? [String: Any] {
            print(
                "[PassportDiagnostics] section=passport_metadata keys=\(metadata.keys.sorted().joined(separator: ",")) null_keys=\(nullKeyList(in: metadata))"
            )
        } else {
            print("[PassportDiagnostics] section=passport_metadata kind=\(kindDescription(for: root["passport_metadata"]))")
        }

        if let sharingSummary = root["sharing_summary"] as? [String: Any] {
            print(
                "[PassportDiagnostics] section=sharing_summary keys=\(sharingSummary.keys.sorted().joined(separator: ",")) null_keys=\(nullKeyList(in: sharingSummary))"
            )
        } else {
            print("[PassportDiagnostics] section=sharing_summary kind=\(kindDescription(for: root["sharing_summary"]))")
        }

        if let verificationSummary = root["verification_summary"] as? [String: Any] {
            print(
                "[PassportDiagnostics] section=verification_summary keys=\(verificationSummary.keys.sorted().joined(separator: ",")) null_keys=\(nullKeyList(in: verificationSummary))"
            )
            for (key, value) in verificationSummary.sorted(by: { $0.key < $1.key }) {
                if let section = value as? [String: Any] {
                    print(
                        "[PassportDiagnostics] section=verification_summary.\(key) keys=\(section.keys.sorted().joined(separator: ",")) null_keys=\(nullKeyList(in: section))"
                    )
                } else {
                    print("[PassportDiagnostics] section=verification_summary.\(key) kind=\(kindDescription(for: value))")
                }
            }
        } else {
            print("[PassportDiagnostics] section=verification_summary kind=\(kindDescription(for: root["verification_summary"]))")
        }

        if let vault = root["vault"] as? [String: Any] {
            print(
                "[PassportDiagnostics] section=vault keys=\(vault.keys.sorted().joined(separator: ",")) null_keys=\(nullKeyList(in: vault))"
            )
            for key in [
                "employments",
                "educations",
                "internships",
                "freelance",
                "gig_platforms",
                "portfolio",
                "certifications",
                "skills",
                "projects",
                "user_documents"
            ] {
                logVaultCollection(name: key, value: vault[key])
            }
        } else {
            print("[PassportDiagnostics] section=vault kind=\(kindDescription(for: root["vault"]))")
        }
    }

    nonisolated static func logPassportSectionDecodeFailure(
        section: String,
        error: DecodingError
    ) {
        print("[PassportDiagnostics] section_decode_failure section=\(section) \(decodingErrorSummary(error))")
    }

    nonisolated static func logPassportDecodeFailure(path: String, error: DecodingError) {
        print("[PassportDiagnostics] decode_failure path=\(path) \(decodingErrorSummary(error))")
    }

    private nonisolated static func logVaultCollection(name: String, value: Any?) {
        guard let value else {
            print("[PassportDiagnostics] section=vault.\(name) kind=missing")
            return
        }

        if value is NSNull {
            print("[PassportDiagnostics] section=vault.\(name) kind=null")
            return
        }

        guard let array = value as? [Any] else {
            print("[PassportDiagnostics] section=vault.\(name) kind=\(kindDescription(for: value))")
            return
        }

        var summary = "[PassportDiagnostics] section=vault.\(name) kind=array count=\(array.count)"

        if let firstObject = array.first as? [String: Any] {
            summary += " first_item_keys=\(firstObject.keys.sorted().joined(separator: ","))"
            summary += " first_item_null_keys=\(nullKeyList(in: firstObject))"
        }

        print(summary)
    }

    private nonisolated static func nullKeyList(in object: [String: Any]) -> String {
        let keys = object
            .compactMap { $0.value is NSNull ? $0.key : nil }
            .sorted()

        return keys.isEmpty ? "-" : keys.joined(separator: ",")
    }

    private nonisolated static func kindDescription(for value: Any?) -> String {
        guard let value else {
            return "missing"
        }

        if value is NSNull {
            return "null"
        }

        switch value {
        case is [String: Any]:
            return "object"
        case is [Any]:
            return "array"
        case is String:
            return "string"
        case is NSNumber:
            return "number_or_bool"
        default:
            return String(reflecting: type(of: value))
        }
    }

    private nonisolated static func decodingErrorSummary(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            return "kind=keyNotFound key=\(key.stringValue) coding_path=\(codingPathString(context.codingPath)) debug=\(sanitize(context.debugDescription))"
        case .typeMismatch(let type, let context):
            return "kind=typeMismatch expected=\(String(reflecting: type)) coding_path=\(codingPathString(context.codingPath)) debug=\(sanitize(context.debugDescription))"
        case .valueNotFound(let type, let context):
            return "kind=valueNotFound expected=\(String(reflecting: type)) coding_path=\(codingPathString(context.codingPath)) debug=\(sanitize(context.debugDescription))"
        case .dataCorrupted(let context):
            return "kind=dataCorrupted coding_path=\(codingPathString(context.codingPath)) debug=\(sanitize(context.debugDescription))"
        @unknown default:
            return "kind=unknown"
        }
    }

    private nonisolated static func codingPathString(_ codingPath: [CodingKey]) -> String {
        let components = codingPath.map { key in
            if let intValue = key.intValue {
                return "[\(intValue)]"
            }
            return key.stringValue
        }

        return components.isEmpty ? "<root>" : components.joined(separator: ".")
    }

    private nonisolated static func sanitize(_ value: String) -> String {
        value.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\"", with: "'")
    }
}
#endif
