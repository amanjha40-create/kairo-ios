import Foundation
import OSLog

// Deliberately accepts no arbitrary messages, errors, payloads, or query values.
nonisolated enum GoogleReturnDiagnostics {
    enum Event: String, Sendable, CaseIterable {
        case appLaunch = "IOS_OAUTH_APP_LAUNCH"
        case sceneActive = "IOS_OAUTH_SCENE_ACTIVE"
        case sceneChanged = "IOS_OAUTH_SCENE_CHANGED"
        case openURLReceived = "IOS_OAUTH_OPENURL_RECEIVED"
        case userActivityReceived = "IOS_OAUTH_USER_ACTIVITY_RECEIVED"
        case linkValidated = "IOS_OAUTH_LINK_VALIDATED"
        case routerReceived = "IOS_OAUTH_ROUTER_RECEIVED"
        case presentationCreated = "IOS_OAUTH_PRESENTATION_CREATED"
        case exchangeStarted = "IOS_OAUTH_EXCHANGE_STARTED"
        case exchangeRequestSent = "IOS_OAUTH_EXCHANGE_REQUEST_SENT"
        case exchangeResponse = "IOS_OAUTH_EXCHANGE_RESPONSE"
        case exchangeFinished = "IOS_OAUTH_EXCHANGE_FINISHED"
        case exchangeFailed = "IOS_OAUTH_EXCHANGE_FAILED"
        case bootstrapStarted = "IOS_OAUTH_BOOTSTRAP_STARTED"
        case bootstrapSucceeded = "IOS_OAUTH_BOOTSTRAP_SUCCEEDED"
        case bootstrapFailed = "IOS_OAUTH_BOOTSTRAP_FAILED"
        case authRootChanged = "IOS_OAUTH_AUTH_ROOT_CHANGED"
    }

    enum State: String, Sendable {
        case active, inactive, background, unknown
        case accepted, rejected, welcome, login, onboarding, mainTabs
    }

    struct LinkMetadata: Sendable {
        let host: String
        let path: String
        let hasCode: Bool

        init(_ url: URL?) {
            let host = url?.host?.lowercased()
            self.host = ["api.kairoid.com", "staging-api.kairoid.com"].contains(host ?? "")
                ? host! : "other"
            self.path = url?.path == "/auth/google/complete" ? "/auth/google/complete" : "other"
            hasCode = url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?
                .queryItems?.contains(where: { $0.name == "code" && !($0.value ?? "").isEmpty }) == true
        }
    }

    @TaskLocal static var deliveryAttemptID: UUID?
    private static let logger = Logger(subsystem: "com.kairoid.Kairo", category: "GoogleReturn")

    static func message(
        _ event: Event, deliveryID: UUID? = nil, state: State? = nil,
        link: LinkMetadata? = nil, httpStatus: Int? = nil,
        requestID: UUID? = nil, correlationID: UUID? = nil
    ) -> String {
        var fields = [event.rawValue]
        if let id = deliveryID ?? deliveryAttemptID { fields.append("deliveryAttemptID=\(id.uuidString)") }
        if let state { fields.append("state=\(state.rawValue)") }
        if let link {
            fields += ["host=\(link.host)", "path=\(link.path)", "hasCode=\(link.hasCode)"]
        }
        if let httpStatus, (100...599).contains(httpStatus) { fields.append("httpStatus=\(httpStatus)") }
        if let requestID { fields.append("requestID=\(requestID.uuidString)") }
        if let correlationID { fields.append("correlationID=\(correlationID.uuidString)") }
        return fields.joined(separator: " ")
    }

    static func emit(
        _ event: Event, deliveryID: UUID? = nil, state: State? = nil,
        link: LinkMetadata? = nil, httpStatus: Int? = nil,
        requestID: UUID? = nil, correlationID: UUID? = nil
    ) {
        // OSLog supplies the timestamp. Only the typed, sanitized record is public.
        let record = message(event, deliveryID: deliveryID, state: state, link: link,
                             httpStatus: httpStatus, requestID: requestID, correlationID: correlationID)
        logger.notice("\(record, privacy: .public)")
    }
}
