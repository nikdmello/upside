import Foundation

protocol HomeRemoteSyncing {
    func pull(role: UserRole) async throws -> HomePersistenceSnapshot?
    func push(_ snapshot: HomePersistenceSnapshot, role: UserRole) async throws
}

enum HomeRemoteSyncError: LocalizedError {
    case missingConfiguration
    case invalidURL
    case invalidResponse
    case conflict(HomePersistenceSnapshot?)
    case unexpectedStatusCode(Int)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Remote sync is not configured."
        case .invalidURL:
            return "Remote sync URL is invalid."
        case .invalidResponse:
            return "Remote sync response was invalid."
        case .conflict:
            return "Remote state is newer than local state."
        case .unexpectedStatusCode(let code):
            return "Remote sync failed with status \(code)."
        }
    }
}

private struct HomeRemoteSyncConflictEnvelope: Decodable {
    let detail: String?
    let current: HomePersistenceSnapshot?
}

struct HomeRemoteSyncConfiguration {
    let baseURL: URL
    let authToken: String?
    let statePath: String

    static func fromBundle(_ bundle: Bundle = .main) -> HomeRemoteSyncConfiguration? {
        let environment = ProcessInfo.processInfo.environment

        func value(for key: String) -> String? {
            if
                let bundleValue = bundle.object(forInfoDictionaryKey: key) as? String,
                !bundleValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                return bundleValue.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if
                let envValue = environment[key],
                !envValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                return envValue.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            return nil
        }

        guard
            let rawBaseURL = value(for: "BACKEND_BASE_URL"),
            let baseURL = URL(string: rawBaseURL)
        else {
            return nil
        }

        let rawPath = value(for: "BACKEND_HOME_STATE_PATH")
        let statePath = (rawPath?.isEmpty == false ? rawPath! : "v1/home-state/me")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        let token = value(for: "BACKEND_AUTH_TOKEN") ?? value(for: "BACKEND_API_TOKEN")

        return HomeRemoteSyncConfiguration(
            baseURL: baseURL,
            authToken: token?.isEmpty == false ? token : nil,
            statePath: statePath
        )
    }
}

final class HomeRemoteSyncService: HomeRemoteSyncing {
    private let configuration: HomeRemoteSyncConfiguration
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(configuration: HomeRemoteSyncConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        self.decoder = decoder
    }

    static func makeDefault(bundle: Bundle = .main, session: URLSession = .shared) -> HomeRemoteSyncService? {
        guard let configuration = HomeRemoteSyncConfiguration.fromBundle(bundle) else {
            return nil
        }
        return HomeRemoteSyncService(configuration: configuration, session: session)
    }

    func pull(role: UserRole) async throws -> HomePersistenceSnapshot? {
        var request = try request(for: role, method: "GET")
        request.httpBody = nil

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HomeRemoteSyncError.invalidResponse
        }

        if http.statusCode == 404 {
            return nil
        }

        guard (200..<300).contains(http.statusCode) else {
            throw HomeRemoteSyncError.unexpectedStatusCode(http.statusCode)
        }

        guard !data.isEmpty else {
            return nil
        }

        return try decoder.decode(HomePersistenceSnapshot.self, from: data)
    }

    func push(_ snapshot: HomePersistenceSnapshot, role: UserRole) async throws {
        var request = try request(for: role, method: "PUT")
        request.httpBody = try encoder.encode(snapshot)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HomeRemoteSyncError.invalidResponse
        }

        if http.statusCode == 409 {
            let envelope = try? decoder.decode(HomeRemoteSyncConflictEnvelope.self, from: data)
            throw HomeRemoteSyncError.conflict(envelope?.current)
        }

        guard (200..<300).contains(http.statusCode) else {
            throw HomeRemoteSyncError.unexpectedStatusCode(http.statusCode)
        }
    }

    private func request(for role: UserRole, method: String) throws -> URLRequest {
        let baseEndpoint = configuration.baseURL
            .appendingPathComponent(configuration.statePath)

        guard baseEndpoint.scheme != nil, baseEndpoint.host != nil else {
            throw HomeRemoteSyncError.invalidURL
        }

        guard var components = URLComponents(url: baseEndpoint, resolvingAgainstBaseURL: false) else {
            throw HomeRemoteSyncError.invalidURL
        }
        var queryItems = components.queryItems ?? []
        queryItems.removeAll(where: { $0.name == "role" })
        queryItems.append(URLQueryItem(name: "role", value: role.rawValue))
        components.queryItems = queryItems

        guard let endpoint = components.url else {
            throw HomeRemoteSyncError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ios", forHTTPHeaderField: "X-Client-Platform")

        if let token = configuration.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }
}
