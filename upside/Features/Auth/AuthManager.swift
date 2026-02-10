import Foundation
import AuthenticationServices
import Combine

class AuthManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var user: User?
    @Published var authError: String?

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
            self.user = User(id: UUID().uuidString, email: email, name: "Demo User")
            self.isAuthenticated = true
        }
    }

    func signInWithGoogle() {
        // TODO: Implement Google Sign In SDK
        // For now, simulate success
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.user = User(id: UUID().uuidString, email: "demo@gmail.com", name: "Google User")
            self.isAuthenticated = true
        }
    }

    func signInDemo() {
        user = User(id: "demo", email: "demo@upside.com", name: "Demo User")
        isAuthenticated = true
    }

    func signOut() {
        user = nil
        isAuthenticated = false
    }
}

extension AuthManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userID = appleIDCredential.user
            let email = appleIDCredential.email ?? ""
            let fullName = appleIDCredential.fullName
            let name = [fullName?.givenName, fullName?.familyName].compactMap { $0 }.joined(separator: " ")

            DispatchQueue.main.async {
                self.user = User(id: userID, email: email, name: name.isEmpty ? "Apple User" : name)
                self.isAuthenticated = true
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        DispatchQueue.main.async {
            self.authError = error.localizedDescription
        }
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

struct User {
    let id: String
    let email: String
    let name: String
}
