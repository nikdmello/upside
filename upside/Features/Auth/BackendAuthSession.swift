import Foundation

actor BackendAuthSession {
    static let shared = BackendAuthSession()
    static let persistedTokenKey = "backend.auth.bearerToken"

    private let defaults: UserDefaults
    private var currentUser: User?
    private var bearerToken: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        bearerToken = defaults.string(forKey: Self.persistedTokenKey)
    }

    func apply(user: User, bearerToken: String?) {
        currentUser = user
        self.bearerToken = bearerToken
        if let bearerToken, !bearerToken.isEmpty {
            defaults.set(bearerToken, forKey: Self.persistedTokenKey)
        } else {
            defaults.removeObject(forKey: Self.persistedTokenKey)
        }
    }

    func clear() {
        currentUser = nil
        bearerToken = nil
        defaults.removeObject(forKey: Self.persistedTokenKey)
    }

    func authorizationToken(fallbackToken: String?) -> String? {
        bearerToken ?? fallbackToken
    }
}
