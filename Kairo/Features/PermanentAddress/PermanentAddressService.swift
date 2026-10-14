import Foundation
import SwiftUI

protocol PermanentAddressServing: Sendable {
    var enabled: Bool { get }
    func state() async throws -> PermanentAddressState
    func save(_ address: ClaimedPermanentAddress) async throws -> PermanentAddressState
    func policy() async throws -> AddressDocumentPolicy
    func document(version: String) async throws -> AddressDocumentState
    func upload(version: String, type: String, file: URL, issued: String?) async throws -> AddressDocumentState
    func submit(version: String, document: String) async throws -> PermanentAddressState
    func start(version: String) async throws -> AddressLocationChallenge
    func complete(_ challenge: AddressLocationChallenge, samples: [AddressLocationSample]) async throws -> PermanentAddressState
    func cancel(_ challenge: AddressLocationChallenge) async throws
}
actor PermanentAddressService: PermanentAddressServing {
    nonisolated let enabled: Bool
    private let session: any SessionServiceProtocol
    private let transfer: SecureDocumentTransferClient
    init(session: any SessionServiceProtocol, enabled: Bool, transfer: SecureDocumentTransferClient = .init()) {
        self.session = session; self.enabled = enabled; self.transfer = transfer
    }
    private func id(_ value: String) throws -> String {
        guard UUID(uuidString: value) != nil else { throw NetworkError.invalidURL }; return value
    }
    private func request<T: Decodable & Sendable>(_ suffix: String = "", method: HTTPMethod = .get, body: Data? = nil, retainChallengeOnCancellation: Bool = false) async throws -> T {
        guard enabled else { throw NetworkError.unavailableInDemoMode }
        try Task.checkCancellation()
        let data = try await session.sendAuthenticated(.init(path: "/permanent-address" + suffix, method: method,
            headers: ["Accept":"application/json", "Content-Type":"application/json", "Cache-Control":"no-store"], body: body,
            allowsSessionRefreshOnUnauthorized: method == .get, requiresPrivateJSONTransport: true))
        if !retainChallengeOnCancellation { try Task.checkCancellation() }
        return try APIJSONCoder.makeDecoder().decode(T.self, from: data)
    }
    func state() async throws -> PermanentAddressState { try await request() }
    func save(_ address: ClaimedPermanentAddress) async throws -> PermanentAddressState {
        guard address.isValid else { throw NetworkError.invalidResponse }
        return try await request(method: .put, body: APIJSONCoder.makeEncoder().encode(address))
    }
    func policy() async throws -> AddressDocumentPolicy { try await request("/document-types") }
    func document(version: String) async throws -> AddressDocumentState { try await request("/\(id(version))/document") }
    func upload(version: String, type: String, file: URL, issued: String?) async throws -> AddressDocumentState {
        let policy = try await policy()
        guard let selected = policy.items.first(where: { $0.value == type }), selected.maxAgeDays == nil || !(issued ?? "").isEmpty else { throw NetworkError.invalidResponse }
        let selection = try await transfer.prepare(fileURL: file, maximumBytes: policy.maxBytes,
            allowedContentTypes: Set(policy.allowedContentTypes).intersection(SecureDocumentTransferClient.vaultContentTypes))
        struct Input: Encodable, Sendable {
            let addressVersionId: String; let documentType: String; let originalFilename: String
            let contentType: String; let byteSize: Int; let issuedOn: String?
        }
        struct Intent: Decodable, Sendable { let documentId: String; let uploadUrl: URL; let headersRequired: [String:String] }
        let intent: Intent = try await request("/documents/upload-intent", method: .post, body: APIJSONCoder.makeEncoder().encode(Input(
            addressVersionId: id(version), documentType: type, originalFilename: selection.filename,
            contentType: selection.contentType, byteSize: selection.data.count, issuedOn: issued)))
        try Task.checkCancellation()
        // Never forward Candidate auth headers/cookies to storage. Keep the capability transient.
        guard intent.uploadUrl.scheme == "https", intent.uploadUrl.user == nil, intent.uploadUrl.password == nil,
              intent.headersRequired.keys.allSatisfy({ !["authorization", "cookie", "proxy-authorization"].contains($0.lowercased()) }) else { throw SecureDocumentTransferError.invalidUploadURL }
        try await transfer.upload(selection, to: intent.uploadUrl, requiredHeaders: intent.headersRequired)
        try Task.checkCancellation()
        return try await request("/documents/\(id(intent.documentId))/complete-upload", method: .post,
            body: APIJSONCoder.makeEncoder().encode(["address_version_id": version, "checksum_sha256": selection.checksumSHA256]))
    }
    func submit(version: String, document: String) async throws -> PermanentAddressState {
        struct Input: Encodable, Sendable { let addressVersionId: String; let documentId: String; let confirmsCurrentAddress = true }
        return try await request("/documents/submit", method: .post, body: APIJSONCoder.makeEncoder().encode(Input(addressVersionId: id(version), documentId: id(document))))
    }
    func start(version: String) async throws -> AddressLocationChallenge {
        try await request("/sessions", method: .post, body: APIJSONCoder.makeEncoder().encode(["address_version_id": id(version)]), retainChallengeOnCancellation: true)
    }
    func complete(_ challenge: AddressLocationChallenge, samples: [AddressLocationSample]) async throws -> PermanentAddressState {
        struct Input: Encodable, Sendable { let challenge: String; let samples: [AddressLocationSample] }
        return try await request("/sessions/\(id(challenge.sessionId))/complete", method: .post,
            body: APIJSONCoder.makeEncoder().encode(Input(challenge: challenge.challenge, samples: samples)))
    }
    func cancel(_ challenge: AddressLocationChallenge) async throws {
        let _: PermanentAddressState = try await request("/sessions/\(id(challenge.sessionId))/cancel", method: .post,
            body: APIJSONCoder.makeEncoder().encode(["challenge": challenge.challenge]))
    }
}
private struct PermanentAddressServiceKey: EnvironmentKey { static let defaultValue: (any PermanentAddressServing)? = nil }
extension EnvironmentValues {
    var permanentAddressService: (any PermanentAddressServing)? {
        get { self[PermanentAddressServiceKey.self] }
        set { self[PermanentAddressServiceKey.self] = newValue }
    }
}
