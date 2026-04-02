import Foundation
import Combine

@MainActor
final class AppSessionStore: ObservableObject {
    static let shared = AppSessionStore()

    @Published private(set) var isAuthenticated: Bool
    @Published private(set) var userRole: UserRole?
    @Published private(set) var currentUser: User?

    private let defaults: UserDefaults

    init(
        defaults: UserDefaults = .standard,
        configuredAuthToken: String? = nil
    ) {
        self.defaults = defaults

        let isAuthenticated = defaults.bool(forKey: Keys.isAuthenticated)
        let userRole = defaults.string(forKey: Keys.userRole).flatMap(UserRole.init(rawValue:))
        let currentUser = defaults.data(forKey: Keys.user).flatMap {
            try? JSONDecoder().decode(User.self, from: $0)
        }
        let resolvedConfiguredAuthToken: String?
        if let configuredAuthToken {
            let trimmedToken = configuredAuthToken.trimmingCharacters(in: .whitespacesAndNewlines)
            resolvedConfiguredAuthToken = trimmedToken.isEmpty ? nil : trimmedToken
        } else {
            resolvedConfiguredAuthToken =
                BackendRuntimeConfiguration.value(for: "BACKEND_AUTH_TOKEN") ??
                BackendRuntimeConfiguration.value(for: "BACKEND_API_TOKEN")
        }
        let hasBackendAuthorization =
            defaults.string(forKey: BackendAuthSession.persistedTokenKey) != nil ||
            resolvedConfiguredAuthToken != nil

        if isAuthenticated, let userRole, hasBackendAuthorization {
            self.isAuthenticated = true
            self.userRole = userRole
            self.currentUser = currentUser
        } else {
            self.isAuthenticated = false
            self.userRole = nil
            self.currentUser = nil
            defaults.removeObject(forKey: Keys.isAuthenticated)
            defaults.removeObject(forKey: Keys.userRole)
            defaults.removeObject(forKey: Keys.user)
        }
    }

    func completeSignIn(role: UserRole, user: User?) {
        isAuthenticated = true
        userRole = role
        currentUser = user

        defaults.set(true, forKey: Keys.isAuthenticated)
        defaults.set(role.rawValue, forKey: Keys.userRole)
        if let user, let data = try? JSONEncoder().encode(user) {
            defaults.set(data, forKey: Keys.user)
        } else {
            defaults.removeObject(forKey: Keys.user)
        }
    }

    func signOut() {
        isAuthenticated = false
        userRole = nil
        currentUser = nil

        defaults.removeObject(forKey: Keys.isAuthenticated)
        defaults.removeObject(forKey: Keys.userRole)
        defaults.removeObject(forKey: Keys.user)

        Task {
            await BackendAuthSession.shared.clear()
        }
    }
}

private enum Keys {
    static let isAuthenticated = "app.session.isAuthenticated"
    static let userRole = "app.session.userRole"
    static let user = "app.session.user"
}
