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
}
#endif
