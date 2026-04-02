import Foundation

protocol BackendIdentityServing {
    func fetchCurrentUser(bearerToken: String) async throws -> BackendIdentity
}

struct BackendIdentity: Decodable {
    let userId: String
    let email: String?
}

enum BackendIdentityError: LocalizedError {
    case missingConfiguration
    case invalidURL
    case invalidResponse
    case missingToken
    case unauthorized
    case unexpectedStatusCode(Int)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Backend auth verification is not configured."
        case .invalidURL:
            return "Backend auth URL is invalid."
        case .invalidResponse:
            return "Backend auth response was invalid."
        case .missingToken:
            return "No backend auth token is available."
        case .unauthorized:
            return "The backend rejected this sign-in."
        case .unexpectedStatusCode(let code):
            return "Backend auth failed with status \(code)."
        }
    }
}

struct BackendIdentityConfiguration {
    let baseURL: URL
    let mePath: String

    static func fromBundle(_ bundle: Bundle = .main) -> BackendIdentityConfiguration? {
        guard
            let rawBaseURL = BackendRuntimeConfiguration.value(for: "BACKEND_BASE_URL", bundle: bundle),
            let baseURL = URL(string: rawBaseURL)
        else {
            return nil
        }

        let mePath = (BackendRuntimeConfiguration.value(for: "BACKEND_AUTH_ME_PATH", bundle: bundle) ?? "v1/auth/me")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        return BackendIdentityConfiguration(baseURL: baseURL, mePath: mePath)
    }
}

final class BackendIdentityService: BackendIdentityServing {
    private let configuration: BackendIdentityConfiguration
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(configuration: BackendIdentityConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    static func makeDefault(bundle: Bundle = .main, session: URLSession = .shared) -> BackendIdentityService? {
        guard let configuration = BackendIdentityConfiguration.fromBundle(bundle) else {
            return nil
        }
        return BackendIdentityService(configuration: configuration, session: session)
    }

    func fetchCurrentUser(bearerToken: String) async throws -> BackendIdentity {
        let trimmedToken = bearerToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            throw BackendIdentityError.missingToken
        }

        let endpoint = configuration.baseURL.appendingPathComponent(configuration.mePath)
        guard endpoint.scheme != nil, endpoint.host != nil else {
            throw BackendIdentityError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(trimmedToken)", forHTTPHeaderField: "Authorization")
        request.setValue("ios", forHTTPHeaderField: "X-Client-Platform")
        request.setValue(UUID().uuidString.lowercased(), forHTTPHeaderField: "X-Request-ID")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BackendIdentityError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 {
                throw BackendIdentityError.unauthorized
            }
            throw BackendIdentityError.unexpectedStatusCode(http.statusCode)
        }

        do {
            return try decoder.decode(BackendIdentity.self, from: data)
        } catch {
            throw BackendIdentityError.invalidResponse
        }
    }
}
