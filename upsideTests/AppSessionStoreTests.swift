import Foundation
import Testing
@testable import upside

struct AppSessionStoreTests {

    @MainActor
    @Test func completeSignInPersistsRoleAndUserWhenBackendAuthorizationExists() throws {
        let suiteName = "AppSessionStoreTests.completeSignInPersistsRoleAndUserWhenBackendAuthorizationExists"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("persisted-token", forKey: BackendAuthSession.persistedTokenKey)

        let user = User(id: "user-1", email: "creator@upside.app", name: "Creator One")
        let store = AppSessionStore(defaults: defaults, configuredAuthToken: "")
        store.completeSignIn(role: .creator, user: user)

        let restored = AppSessionStore(defaults: defaults, configuredAuthToken: "")

        #expect(restored.isAuthenticated)
        #expect(restored.userRole == .creator)
        #expect(restored.currentUser == user)
    }

    @MainActor
    @Test func staleAuthenticatedStateIsClearedWhenBackendAuthorizationIsMissing() throws {
        let suiteName = "AppSessionStoreTests.staleAuthenticatedStateIsClearedWhenBackendAuthorizationIsMissing"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let user = User(id: "user-2", email: "brand@upside.app", name: "Brand Two")
        defaults.set(true, forKey: "app.session.isAuthenticated")
        defaults.set(UserRole.brand.rawValue, forKey: "app.session.userRole")
        defaults.set(try JSONEncoder().encode(user), forKey: "app.session.user")

        let restored = AppSessionStore(defaults: defaults, configuredAuthToken: "")

        #expect(restored.isAuthenticated == false)
        #expect(restored.userRole == nil)
        #expect(restored.currentUser == nil)
        #expect(defaults.object(forKey: "app.session.isAuthenticated") == nil)
        #expect(defaults.object(forKey: "app.session.userRole") == nil)
        #expect(defaults.object(forKey: "app.session.user") == nil)
    }
}
