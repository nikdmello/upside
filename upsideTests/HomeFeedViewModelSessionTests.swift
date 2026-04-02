import Foundation
import Testing
@testable import upside

struct HomeFeedViewModelSessionTests {

    @MainActor
    @Test func unauthorizedRemoteSyncRequiresReauthentication() async throws {
        let viewModel = HomeFeedViewModel(
            userRole: .brand,
            dataStore: InMemoryHomeDataStore(),
            remoteSync: UnauthorizedRemoteSync(),
            remoteFeed: nil
        )

        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(viewModel.requiresReauthentication)
        #expect(viewModel.reauthenticationMessage == "Your session expired. Sign in again to reconnect to Upside.")

        if case .failed(let message) = viewModel.syncState {
            #expect(message == "Session expired. Sign in again.")
        } else {
            Issue.record("Expected sync state to fail with a session-expired message.")
        }
    }
}

private struct InMemoryHomeDataStore: HomeDataStore {
    func load(role: UserRole) -> HomePersistenceSnapshot? { nil }
    func save(_ snapshot: HomePersistenceSnapshot, role: UserRole) {}
    func clear(role: UserRole) {}
}

private struct UnauthorizedRemoteSync: HomeRemoteSyncing {
    func pull(role: UserRole) async throws -> HomePersistenceSnapshot? {
        throw HomeRemoteSyncError.unauthorized
    }

    func push(_ snapshot: HomePersistenceSnapshot, role: UserRole, idempotencyKey: String) async throws {
        throw HomeRemoteSyncError.unauthorized
    }
}
