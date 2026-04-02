import Foundation
import Testing
@testable import upside

struct HomeRemoteSyncServiceTests {

    @MainActor
    @Test func pushAddsProvidedIdempotencyKeyAndAuthHeaders() async throws {
        let recorder = RequestRecorder()
        MockURLProtocol.requestHandler = { request in
            await recorder.record(request)
            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 204,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                Data()
            )
        }
        defer { MockURLProtocol.requestHandler = nil }

        let service = HomeRemoteSyncService(
            configuration: HomeRemoteSyncConfiguration(
                baseURL: URL(string: "https://api.upside.app")!,
                fallbackAuthToken: "test-token",
                statePath: "v1/home-state/me"
            ),
            session: makeMockSession()
        )

        let snapshot = HomePersistenceSnapshot(
            lastUpdatedAt: Date(timeIntervalSince1970: 1_763_500_000),
            filters: HomeFilters(),
            profile: HomeProfileDraft(
                displayName: "Upside Demo",
                headline: "Brand • Growth",
                bio: "Demo profile",
                location: "Dubai",
                email: "demo@upside.app",
                websiteOrHandle: "upside.app"
            ),
            conversations: [],
            swipedCardKeys: ["creator-@nikdmello"],
            savedCardKeys: ["creator-@mikethurston"]
        )

        let idempotencyKey = "home-state-brand-test-key"

        try await service.push(snapshot, role: UserRole.brand, idempotencyKey: idempotencyKey)
        let firstRequest = try #require(await recorder.lastRequest)

        try await service.push(snapshot, role: UserRole.brand, idempotencyKey: idempotencyKey)
        let secondRequest = try #require(await recorder.lastRequest)

        #expect(firstRequest.httpMethod == "PUT")
        #expect(firstRequest.url?.absoluteString == "https://api.upside.app/v1/home-state/me?role=brand")
        #expect(firstRequest.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        #expect(firstRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(firstRequest.value(forHTTPHeaderField: "X-Client-Platform") == "ios")
        #expect(firstRequest.value(forHTTPHeaderField: "X-Request-ID")?.isEmpty == false)
        #expect(firstRequest.value(forHTTPHeaderField: "Idempotency-Key") == idempotencyKey)
        #expect(secondRequest.value(forHTTPHeaderField: "Idempotency-Key") == idempotencyKey)
    }
}

private actor RequestRecorder {
    private(set) var lastRequest: URLRequest?

    func record(_ request: URLRequest) {
        lastRequest = request
    }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    static var requestHandler: (@Sendable (URLRequest) async throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        Task {
            do {
                let (response, data) = try await handler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {}
}

private func makeMockSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: configuration)
}
