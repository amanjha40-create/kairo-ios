import Foundation

struct APIConfiguration: Equatable, Sendable {
    let baseURL: URL

    static func make(for environment: AppEnvironment) -> APIConfiguration {
        APIConfiguration(baseURL: baseURL(for: environment))
    }

    static func baseURL(for environment: AppEnvironment) -> URL {
        switch environment {
        case .development:
            URL(string: "http://localhost:8000/api/v1")!
        case .staging:
            URL(string: "https://staging-api.kairoid.com/api/v1")!
        case .production:
            URL(string: "https://api.kairoid.com/api/v1")!
        }
    }
}
