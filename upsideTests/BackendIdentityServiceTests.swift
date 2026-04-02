import Foundation
import Testing
@testable import upside

struct BackendIdentityServiceTests {

    @Test func fetchCurrentUserAddsAuthHeadersAndParsesIdentity() async throws {
        let recorder = IdentityRequestRecorder()
        IdentityMockURLProtocol.requestHandler = { request in
            await recorder.record(request)
            let responseBody = """
            {
              "userId": "backend-user-1",
              "email": "backend@upside.app"
            }
            """.data(using: .utf8) ?? Data()
            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!,
                responseBody
            )
        }
        defer { IdentityMockURLProtocol.requestHandler = nil }

        let service = BackendIdentityService(
            configuration: BackendIdentityConfiguration(
                baseURL: URL(string: "https://api.upside.app")!,
                mePath: "v1/auth/me"
            ),
            session: makeIdentityMockSession()
        )

        let identity = try await service.fetchCurrentUser(bearerToken: "test-token")
        let request = try #require(await recorder.lastRequest)

        #expect(identity.userId == "backend-user-1")
        #expect(identity.email == "backend@upside.app")
        #expect(request.httpMethod == "GET")
        #expect(request.url?.absoluteString == "https://api.upside.app/v1/auth/me")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.value(forHTTPHeaderField: "X-Client-Platform") == "ios")
        #expect(request.value(forHTTPHeaderField: "X-Request-ID")?.isEmpty == false)
    }
}

private actor IdentityRequestRecorder {
    private(set) var lastRequest: URLRequest?

    func record(_ request: URLRequest) {
        lastRequest = request
    }
}

private final class IdentityMockURLProtocol: URLProtocol, @unchecked Sendable {
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

private func makeIdentityMockSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [IdentityMockURLProtocol.self]
    return URLSession(configuration: configuration)
}
