import Foundation

struct DemoNetworkClient: NetworkClient {
    func send(_ request: NetworkRequest) async throws -> Data {
        _ = request
        throw NetworkError.unavailableInDemoMode
    }
}
