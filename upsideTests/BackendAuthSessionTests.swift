import Foundation
import Testing
@testable import upside

struct BackendAuthSessionTests {

    @Test func applyPersistsBearerTokenAcrossSessionInstances() async throws {
        let suiteName = "BackendAuthSessionTests.applyPersistsBearerTokenAcrossSessionInstances"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let session = BackendAuthSession(defaults: defaults)
        await session.apply(
            user: User(id: "user-1", email: "creator@upside.app", name: "Creator One"),
            bearerToken: "persisted-bearer-token"
        )

        let restoredSession = BackendAuthSession(defaults: defaults)

        #expect(await restoredSession.authorizationToken(fallbackToken: nil) == "persisted-bearer-token")
    }
}
