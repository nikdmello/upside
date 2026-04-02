import Foundation
import AuthenticationServices
import Combine

@MainActor
class AuthManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var user: User?
    @Published var authError: String?

    private let backendIdentityService: (any BackendIdentityServing)?

    init(backendIdentityService: (any BackendIdentityServing)? = nil) {
        self.backendIdentityService = backendIdentityService ?? BackendIdentityService.makeDefault()
        super.init()
    }

    func signInWithApple() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }

    func signInWithEmail(_ email: String, password: String) {
        // TODO: Implement email/password auth with your backend
        // For now, simulate success
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let signedInUser = User(id: UUID().uuidString, email: email, name: "Demo User")
            Task {
                await self.finishSignIn(user: signedInUser, bearerToken: BackendRuntimeConfiguration.configuredAuthToken())
            }
        }
    }

    func signInWithGoogle() {
        // TODO: Implement Google Sign In SDK
        // For now, simulate success
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let signedInUser = User(id: UUID().uuidString, email: "demo@gmail.com", name: "Google User")
            Task {
                await self.finishSignIn(user: signedInUser, bearerToken: BackendRuntimeConfiguration.configuredAuthToken())
            }
        }
    }

    func signInDemo() {
        let signedInUser = User(id: "demo", email: "demo@upside.com", name: "Demo User")
        user = signedInUser
        isAuthenticated = true
        authError = nil
        Task {
            await BackendAuthSession.shared.clear()
        }
    }

    func signOut() {
        user = nil
        isAuthenticated = false
        authError = nil
        Task {
            await BackendAuthSession.shared.clear()
        }
    }
}

extension AuthManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userID = appleIDCredential.user
            let email = appleIDCredential.email ?? ""
            let fullName = appleIDCredential.fullName
            let name = [fullName?.givenName, fullName?.familyName].compactMap { $0 }.joined(separator: " ")
            let bearerToken = appleIDCredential.identityToken.flatMap { String(data: $0, encoding: .utf8) }
                ?? BackendRuntimeConfiguration.configuredAuthToken()
            let signedInUser = User(id: userID, email: email, name: name.isEmpty ? "Apple User" : name)

            Task {
                await self.finishSignIn(user: signedInUser, bearerToken: bearerToken)
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        DispatchQueue.main.async {
            self.authError = error.localizedDescription
        }
    }
}

private extension AuthManager {
    func finishSignIn(user: User, bearerToken: String?) async {
        do {
            let resolvedUser = try await resolveBackendUser(fallbackUser: user, bearerToken: bearerToken)
            await BackendAuthSession.shared.apply(user: resolvedUser, bearerToken: bearerToken)
            self.user = resolvedUser
            self.isAuthenticated = true
            self.authError = nil
        } catch {
            await BackendAuthSession.shared.clear()
            self.user = nil
            self.isAuthenticated = false
            self.authError = error.localizedDescription
        }
    }

    func resolveBackendUser(fallbackUser: User, bearerToken: String?) async throws -> User {
        guard let backendIdentityService else {
            return fallbackUser
        }

        guard let bearerToken else {
            throw BackendIdentityError.missingToken
        }

        let identity = try await backendIdentityService.fetchCurrentUser(bearerToken: bearerToken)
        let resolvedEmail = identity.email ?? fallbackUser.email
        let resolvedName: String
        if !fallbackUser.name.isEmpty {
            resolvedName = fallbackUser.name
        } else if let email = identity.email, !email.isEmpty {
            resolvedName = email
        } else {
            resolvedName = "Upside User"
        }

        return User(id: identity.userId, email: resolvedEmail, name: resolvedName)
    }
}

extension AuthManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window scene available")
        }
        return window
    }
}

struct User: Codable, Equatable {
    let id: String
    let email: String
    let name: String
}
