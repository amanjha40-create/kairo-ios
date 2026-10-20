import Foundation
import SwiftUI

/// Local certification only. Ordinary builds compile the entry gate permanently off.
/// Even a specially compiled build rejects distribution provisioning.
enum LocalBatch1QA {
    static let argument = "-KAIRO_LOCAL_BATCH1_QA"
    static let preferences = UserDefaults(suiteName: "com.kairoid.localBatch1QA.\(UUID().uuidString)")!

    static func isEnabled(configuration: AppConfiguration,
                          arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
#if KAIRO_LOCAL_BATCH1_QA
        guard configuration.buildConfiguration == .production,
              configuration.environment == .production, !configuration.isDemoModeEnabled,
              arguments.contains(argument),
              arguments.contains(UITestLaunchConfiguration.enabledArgument) else { return false }
#if targetEnvironment(simulator)
        return true
#else
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
              let profile = try? PropertyListSerialization.propertyList(
                from: data[start.lowerBound..<end.upperBound], format: nil) as? [String: Any] else { return false }
        return permitsDevelopmentProfile(profile)
#endif
#else
        return false
#endif
    }

    static func permitsDevelopmentProfile(_ profile: [String: Any], now: Date = Date()) -> Bool {
        guard let entitlements = profile["Entitlements"] as? [String: Any],
              entitlements["get-task-allow"] as? Bool == true,
              entitlements["application-identifier"] as? String == "MVT4T97ZGC.com.kairoid.Kairo",
              entitlements["com.apple.developer.team-identifier"] as? String == "MVT4T97ZGC",
              let devices = profile["ProvisionedDevices"] as? [String], !devices.isEmpty,
              let expiry = profile["ExpirationDate"] as? Date, expiry > now else { return false }
        return true
    }

    static func mode(_ name: String, configuration: AppConfiguration) -> Bool {
        isEnabled(configuration: configuration) && ProcessInfo.processInfo.environment["KAIRO_LOCAL_BATCH1_MODE"] == name
    }
}

/// Delays only disposable reads to display the real restoring-session root.
actor LocalBatch1QADelayedTokens: TokenStore {
    func readToken(for key: TokenKey) async throws -> String? {
        try await Task.sleep(for: .seconds(30))
        return nil
    }
    func save(_ token: String, for key: TokenKey) async throws { throw NetworkError.unavailableInDemoMode }
    func deleteToken(for key: TokenKey) async throws {}
}

struct LocalBatch1QADateEditor: View {
    @State private var result = "Synthetic unknown dates — no writes"
    var body: some View {
        VStack {
            Text(result).accessibilityIdentifier("batch1.dates.result")
            CareerEmploymentEditorSheet(mode: .edit, draft: CareerEmploymentDraft(record: .init(
                id: "synthetic", subjectFullName: nil, subjectEmail: nil, company: "Synthetic",
                employerLegalName: "Synthetic", employerTradeName: nil, role: "Engineer",
                employmentType: "full_time", startDate: nil, endDate: nil, currentlyWorking: false,
                workLocationCountry: nil, workLocationRegion: nil, workArrangement: "remote",
                verificationMethod: "document", verificationStatus: .notVerified, rawVerificationStatus: "draft"))) { draft in
                    let request = draft.updateRequest()
                    result = request.startDate == nil && request.endDate == nil
                        ? "Unknown dates preserved" : "Date integrity failed"
                }
        }
    }
}
