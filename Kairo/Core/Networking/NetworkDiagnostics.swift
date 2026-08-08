import Foundation

#if DEBUG
enum NetworkDiagnostics {
    private nonisolated static let verifyDiagnosticsURL = URL(fileURLWithPath: "/tmp/kairo-verify-diagnostics.log")

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

    nonisolated static func logVerifyResponseShape(path: String, data: Data) {
        guard let rootObject = try? JSONSerialization.jsonObject(with: data) else {
            recordVerify("[VerifyDiagnostics] shape path=\(path) top_level=unreadable_json")
            return
        }

        if let items = rootObject as? [[String: Any]] {
            recordVerify("[VerifyDiagnostics] shape path=\(path) top_level=array item_count=\(items.count)")
            if let first = items.first {
                printVerifyRequestShape(item: first)
            }
            return
        }

        guard let root = rootObject as? [String: Any] else {
            recordVerify("[VerifyDiagnostics] shape path=\(path) top_level=\(kindDescription(for: rootObject))")
            return
        }

        let rootKeys = root.keys.sorted().joined(separator: ",")
        recordVerify("[VerifyDiagnostics] shape path=\(path) top_level=object keys=\(rootKeys)")

        if let items = root["items"] as? [[String: Any]] {
            let paginationKeys = root.keys
                .filter { $0 != "items" }
                .sorted()
                .joined(separator: ",")
            recordVerify("[VerifyDiagnostics] page_wrapper item_count=\(items.count) pagination_keys=\(paginationKeys)")
            if let first = items.first {
                printVerifyRequestShape(item: first)
            }
            return
        }

        recordVerify("[VerifyDiagnostics] shape path=\(path) wrapper_without_items kind=object")
    }

    nonisolated static func logVerifyDecodeFailure(
        path: String,
        primaryError: Error,
        envelopeError: Error?
    ) {
        let primarySummary = decodingSummary(primaryError)
        let envelopeSummary = envelopeError.map(decodingSummary)
        if let envelopeSummary {
            recordVerify("[VerifyDiagnostics] decode_failure path=\(path) primary={\(primarySummary)} envelope={\(envelopeSummary)}")
        } else {
            recordVerify("[VerifyDiagnostics] decode_failure path=\(path) primary={\(primarySummary)}")
        }
    }

    nonisolated static func logVerifyListItemSkipped(index: Int, error: Error) {
        recordVerify("[VerifyDiagnostics] skipped_item index=\(index) error={\(decodingSummary(error))}")
    }

    nonisolated static func logVerifyListItemRoutingFields(index: Int, item: Any) {
        guard let object = item as? [String: Any] else {
            recordVerify("[VerifyDiagnostics] routing_fields index=\(index) kind=\(kindDescription(for: item))")
            return
        }

        let fieldSummary = [
            summarizeVerifyStringField(named: "public_id", in: object),
            summarizeVerifyStringField(named: "trust_invitation_public_id", in: object),
            summarizeVerifyStringField(named: "organization_public_id", in: object),
            summarizeVerifyStringField(named: "request_type", in: object),
            summarizeVerifyStringField(named: "status", in: object)
        ].joined(separator: " ")
        recordVerify("[VerifyDiagnostics] routing_fields index=\(index) \(fieldSummary)")

        if let trustContext = object["trust_context"] as? [String: Any] {
            let keys = trustContext.keys.sorted().joined(separator: ",")
            recordVerify("[VerifyDiagnostics] nested trust_context keys=\(keys)")
        } else {
            recordVerify("[VerifyDiagnostics] nested trust_context=\(kindDescription(for: object["trust_context"]))")
        }
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

    private nonisolated static func printVerifyRequestShape(item: [String: Any]) {
        let itemKeys = item.keys.sorted()
        recordVerify("[VerifyDiagnostics] request_item keys=\(itemKeys.joined(separator: ","))")

        let typeSummary = itemKeys.map { key in
            "\(key):\(kindDescription(for: item[key]))"
        }.joined(separator: ",")
        recordVerify("[VerifyDiagnostics] request_item value_types=\(typeSummary)")

        let nullKeys = item
            .compactMap { $0.value is NSNull ? $0.key : nil }
            .sorted()
            .joined(separator: ",")
        recordVerify("[VerifyDiagnostics] request_item null_keys=\(nullKeys.isEmpty ? "-" : nullKeys)")

        printVerifyNestedShape(name: "organization_summary", value: item["organization_summary"])
        printVerifyNestedShape(name: "verification_target", value: item["verification_target"])
        printVerifyNestedShape(name: "employment_claim", value: item["employment_claim"])
        printVerifyNestedShape(name: "education_claim", value: item["education_claim"])
        printVerifyNestedShape(name: "evidence_summary", value: item["evidence_summary"])

        if let status = item["status"] as? String {
            recordVerify("[VerifyDiagnostics] request_item status=\(status)")
        }
        if let requestType = item["request_type"] as? String {
            recordVerify("[VerifyDiagnostics] request_item request_type=\(requestType)")
        }
        if let priority = item["priority"] as? String {
            recordVerify("[VerifyDiagnostics] request_item priority=\(priority)")
        }
    }

    private nonisolated static func printVerifyNestedShape(name: String, value: Any?) {
        guard let value else {
            recordVerify("[VerifyDiagnostics] nested \(name)=missing")
            return
        }

        if value is NSNull {
            recordVerify("[VerifyDiagnostics] nested \(name)=null")
            return
        }

        guard let object = value as? [String: Any] else {
            recordVerify("[VerifyDiagnostics] nested \(name)=\(kindDescription(for: value))")
            return
        }

        let keys = object.keys.sorted().joined(separator: ",")
        let types = object.keys.sorted().map { key in
            "\(key):\(kindDescription(for: object[key]))"
        }.joined(separator: ",")
        let nullKeys = object
            .compactMap { $0.value is NSNull ? $0.key : nil }
            .sorted()
            .joined(separator: ",")
        recordVerify("[VerifyDiagnostics] nested \(name) keys=\(keys)")
        recordVerify("[VerifyDiagnostics] nested \(name) value_types=\(types)")
        recordVerify("[VerifyDiagnostics] nested \(name) null_keys=\(nullKeys.isEmpty ? "-" : nullKeys)")
    }

    private nonisolated static func summarizeVerifyStringField(
        named key: String,
        in object: [String: Any]
    ) -> String {
        guard let value = object[key] else {
            return "\(key)=missing"
        }

        if value is NSNull {
            return "\(key)=null"
        }

        guard let stringValue = value as? String else {
            return "\(key)=\(kindDescription(for: value))"
        }

        let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(key)=string(len:\(stringValue.count),trimmed_len:\(trimmed.count),nonempty:\(!trimmed.isEmpty))"
    }

    private nonisolated static func recordVerify(_ message: String) {
        print(message)

        let line = message + "\n"
        guard let data = line.data(using: .utf8) else {
            return
        }

        if FileManager.default.fileExists(atPath: verifyDiagnosticsURL.path) {
            if let handle = try? FileHandle(forWritingTo: verifyDiagnosticsURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            }
            return
        }

        try? data.write(to: verifyDiagnosticsURL, options: .atomic)
    }

    private nonisolated static func decodingSummary(_ error: Error) -> String {
        if let decodingError = error as? DecodingError {
            return decodingErrorSummary(decodingError)
        }

        let nsError = error as NSError
        return "kind=nonDecoding type=\(String(reflecting: type(of: error))) domain=\(nsError.domain) code=\(nsError.code)"
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
