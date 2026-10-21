import Foundation

struct APIConfiguration: Equatable, Sendable {
    let baseURL: URL

    static func make(for environment: AppEnvironment) -> APIConfiguration {
        APIConfiguration(baseURL: baseURL(for: environment))
    }

    static func baseURL(for environment: AppEnvironment) -> URL {
        BuildEndpointPolicy.baseURL(for: environment)
    }
}

/// Endpoint definitions only. Production does not compile non-Production hosts.
/// The project sets KAIRO_PRODUCTION for the Production configuration.
nonisolated enum BuildEndpointPolicy {
    static var defaultEnvironment: AppEnvironment {
        #if KAIRO_PRODUCTION
        .production
        #else
        .development
        #endif
    }

    static func baseURL(for environment: AppEnvironment) -> URL {
        #if KAIRO_PRODUCTION
        precondition(environment == .production, "Invalid release endpoint environment")
        return URL(string: "https://api.kairoid.com/api/v1")!
        #else
        switch environment {
        case .development:
            URL(string: "http://localhost:8000/api/v1")!
        case .staging:
            URL(string: "https://staging-api.kairoid.com/api/v1")!
        case .production:
            URL(string: "https://api.kairoid.com/api/v1")!
        }
        #endif
    }

    static var diagnosticHosts: Set<String> {
        #if KAIRO_PRODUCTION
        ["api.kairoid.com"]
        #else
        ["api.kairoid.com", "staging-api.kairoid.com"]
        #endif
    }

    static var developmentShareHosts: Set<String> {
        #if KAIRO_PRODUCTION
        []
        #else
        ["localhost", "127.0.0.1"]
        #endif
    }

    static var stagingShareHosts: Set<String> {
        #if KAIRO_PRODUCTION
        []
        #else
        ["d3kpvsn9kfajzc.cloudfront.net"]
        #endif
    }

    static var stagingAPIBaseURL: URL? {
        #if KAIRO_PRODUCTION
        nil
        #else
        baseURL(for: .staging)
        #endif
    }

    static func stagingCompletionURL(failed: Bool) -> URL {
        #if KAIRO_PRODUCTION
        preconditionFailure("Non-Production endpoint unavailable in release")
        #else
        URL(string: "\(baseURL(for: .staging).absoluteString)/integrations/digilocker/complete?digilocker_result=\(failed ? "failed" : "connected")")!
        #endif
    }
}
