import AuthenticationServices
import CryptoKit
import Security
import SwiftUI

struct FederatedAuthenticationButtons: View {
    var body: some View {
        VStack(spacing: KairoSpacing.small) {
            HStack(spacing: KairoSpacing.small) {
                Rectangle()
                    .fill(KairoColors.border)
                    .frame(height: 1)
                Text("OR")
                    .font(KairoTypography.caption)
                    .foregroundStyle(KairoColors.textSecondary)
                Rectangle()
                    .fill(KairoColors.border)
                    .frame(height: 1)
            }
            .accessibilityHidden(true)

            AppleAuthenticationButton()
            GoogleAuthenticationButton(showsDivider: false)
        }
    }
}

struct AppleAuthenticationButton: View {
    @Environment(\.authService) private var authService
    @EnvironmentObject private var sessionStore: AppSessionStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var currentNonce: String?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: KairoSpacing.small) {
            SignInWithAppleButton(.continue, onRequest: configure, onCompletion: complete)
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(minHeight: 50)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .disabled(isLoading)
                .accessibilityIdentifier(KairoAccessibilityID.appleAuthenticationStart)

            if isLoading {
                ProgressView("Completing Apple sign-in")
                    .font(KairoTypography.footnote)
                    .accessibilityIdentifier(KairoAccessibilityID.appleAuthenticationLoading)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.danger)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(KairoAccessibilityID.appleAuthenticationError)
            }
        }
    }

    private func configure(_ request: ASAuthorizationAppleIDRequest) {
        guard let nonce = Self.randomNonce() else {
            currentNonce = nil
            errorMessage = "Apple sign-in could not start securely. Please try again."
            return
        }
        currentNonce = nonce
        errorMessage = nil
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    private func complete(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error as ASAuthorizationError) where error.code == .canceled:
            currentNonce = nil
            isLoading = false
            errorMessage = nil
        case .failure:
            currentNonce = nil
            isLoading = false
            errorMessage = "Apple sign-in could not be completed. Please try again."
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let nonce = currentNonce,
                let identityTokenData = credential.identityToken,
                let authorizationCodeData = credential.authorizationCode,
                let identityToken = String(data: identityTokenData, encoding: .utf8),
                let authorizationCode = String(data: authorizationCodeData, encoding: .utf8)
            else {
                errorMessage = "Apple returned an incomplete credential. Please try again."
                return
            }

            isLoading = true
            errorMessage = nil
            currentNonce = nil
            let request = AppleSignInRequestDTO(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                nonce: nonce,
                givenName: credential.fullName?.givenName,
                familyName: credential.fullName?.familyName
            )
            Task { await finish(request) }
        }
    }

    @MainActor
    private func finish(_ request: AppleSignInRequestDTO) async {
        defer { isLoading = false }
        do {
            let response = try await authService.signInWithApple(request)
            switch response.outcome {
            case .loginComplete:
                await sessionStore.completeAuthenticationAndRoute()
            case .phoneVerificationRequired:
                guard let signup = response.signup else {
                    errorMessage = "Apple sign-in returned an incomplete signup. Please try again."
                    return
                }
                sessionStore.continueFederatedPhoneSignup(signup)
            case .accountLinkingRequired:
                errorMessage = "An existing KairoID account uses this email. Sign in to that account first; accounts are never linked automatically."
            case .authFailed:
                errorMessage = response.message
            }
        } catch let error as NetworkError {
            errorMessage = switch error {
            case .transport: "KairoID couldn't reach the network. Check your connection and try again."
            case .unavailableInDemoMode: "Apple sign-in is unavailable in Demo Mode."
            case .api, .invalidResponse, .invalidURL: "Apple sign-in could not be completed safely. Please try again."
            }
        } catch {
            errorMessage = "Apple sign-in could not be completed. Please try again."
        }
    }

    private static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func randomNonce() -> String? {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = bytes.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
        }
        guard status == errSecSuccess else { return nil }
        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
