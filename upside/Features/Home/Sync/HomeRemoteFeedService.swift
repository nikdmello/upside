import Foundation

protocol HomeRemoteFeedServing {
    func fetchCards(role: UserRole, limit: Int, offset: Int) async throws -> [HomeCard]
    func recordSwipe(role: UserRole, cardKey: String, action: SwipeAction) async throws
    func clearSwipeHistory(role: UserRole) async throws
}

enum HomeRemoteFeedError: LocalizedError {
    case missingConfiguration
    case invalidURL
    case invalidResponse
    case unauthorized
    case unexpectedStatusCode(Int)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Remote feed is not configured."
        case .invalidURL:
            return "Remote feed URL is invalid."
        case .invalidResponse:
            return "Remote feed response was invalid."
        case .unauthorized:
            return "Unauthorized: check your app auth session or backend token configuration."
        case .unexpectedStatusCode(let code):
            return "Remote feed failed with status \(code)."
        }
    }
}

struct HomeRemoteFeedConfiguration {
    let baseURL: URL
    let fallbackAuthToken: String?
    let feedPath: String
    let swipePath: String
    let swipeResetPath: String

    static func fromBundle(_ bundle: Bundle = .main) -> HomeRemoteFeedConfiguration? {
        guard
            let rawBaseURL = BackendRuntimeConfiguration.value(for: "BACKEND_BASE_URL", bundle: bundle),
            let baseURL = URL(string: rawBaseURL)
        else {
            return nil
        }

        let feedPath = (BackendRuntimeConfiguration.value(for: "BACKEND_FEED_PATH", bundle: bundle) ?? "v1/feed")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let swipePath = (BackendRuntimeConfiguration.value(for: "BACKEND_SWIPE_PATH", bundle: bundle) ?? "v1/swipes")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let swipeResetPath = (BackendRuntimeConfiguration.value(for: "BACKEND_SWIPE_RESET_PATH", bundle: bundle) ?? "v1/swipes/me")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        return HomeRemoteFeedConfiguration(
            baseURL: baseURL,
            fallbackAuthToken: BackendRuntimeConfiguration.configuredAuthToken(bundle: bundle),
            feedPath: feedPath,
            swipePath: swipePath,
            swipeResetPath: swipeResetPath
        )
    }
}

final class HomeRemoteFeedService: HomeRemoteFeedServing {
    private let configuration: HomeRemoteFeedConfiguration
    private let session: URLSession

    init(configuration: HomeRemoteFeedConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    static func makeDefault(bundle: Bundle = .main, session: URLSession = .shared) -> HomeRemoteFeedService? {
        guard !AppTestingConfiguration.enableDemoMode else {
            return nil
        }
        guard let configuration = HomeRemoteFeedConfiguration.fromBundle(bundle) else {
            return nil
        }
        return HomeRemoteFeedService(configuration: configuration, session: session)
    }

    func fetchCards(role: UserRole, limit: Int, offset: Int) async throws -> [HomeCard] {
        var components = try feedComponents(role: role)
        components.queryItems = [
            URLQueryItem(name: "role", value: role.rawValue),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]

        guard let endpoint = components.url else {
            throw HomeRemoteFeedError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ios", forHTTPHeaderField: "X-Client-Platform")
        if let token = await BackendAuthSession.shared.authorizationToken(fallbackToken: configuration.fallbackAuthToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HomeRemoteFeedError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 {
                throw HomeRemoteFeedError.unauthorized
            }
            throw HomeRemoteFeedError.unexpectedStatusCode(http.statusCode)
        }

        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let cardPayloads = root["cards"] as? [[String: Any]]
        else {
            throw HomeRemoteFeedError.invalidResponse
        }

        return cardPayloads.compactMap(Self.parseCard(from:))
    }

    func recordSwipe(role: UserRole, cardKey: String, action: SwipeAction) async throws {
        let endpoint = try swipeEndpoint()

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ios", forHTTPHeaderField: "X-Client-Platform")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
        if let token = await BackendAuthSession.shared.authorizationToken(fallbackToken: configuration.fallbackAuthToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let payload: [String: String] = [
            "role": role.rawValue,
            "cardKey": cardKey,
            "action": action.remoteValue
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HomeRemoteFeedError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 {
                throw HomeRemoteFeedError.unauthorized
            }
            throw HomeRemoteFeedError.unexpectedStatusCode(http.statusCode)
        }
    }

    func clearSwipeHistory(role: UserRole) async throws {
        var components = try swipeResetComponents()
        components.queryItems = [
            URLQueryItem(name: "role", value: role.rawValue)
        ]

        guard let endpoint = components.url else {
            throw HomeRemoteFeedError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ios", forHTTPHeaderField: "X-Client-Platform")
        if let token = await BackendAuthSession.shared.authorizationToken(fallbackToken: configuration.fallbackAuthToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HomeRemoteFeedError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 {
                throw HomeRemoteFeedError.unauthorized
            }
            throw HomeRemoteFeedError.unexpectedStatusCode(http.statusCode)
        }
    }

    private func feedComponents(role: UserRole) throws -> URLComponents {
        _ = role
        let endpoint = configuration.baseURL
            .appendingPathComponent(configuration.feedPath)
        guard endpoint.scheme != nil, endpoint.host != nil else {
            throw HomeRemoteFeedError.invalidURL
        }
        guard let components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw HomeRemoteFeedError.invalidURL
        }
        return components
    }

    private func swipeEndpoint() throws -> URL {
        let endpoint = configuration.baseURL
            .appendingPathComponent(configuration.swipePath)
        guard endpoint.scheme != nil, endpoint.host != nil else {
            throw HomeRemoteFeedError.invalidURL
        }
        return endpoint
    }

    private func swipeResetComponents() throws -> URLComponents {
        let endpoint = configuration.baseURL
            .appendingPathComponent(configuration.swipeResetPath)
        guard endpoint.scheme != nil, endpoint.host != nil else {
            throw HomeRemoteFeedError.invalidURL
        }
        guard let components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw HomeRemoteFeedError.invalidURL
        }
        return components
    }

    private static func parseCard(from raw: [String: Any]) -> HomeCard? {
        guard let cardType = raw["cardType"] as? String else {
            return nil
        }
        let cardKey = raw["cardKey"] as? String

        switch cardType {
        case "brand":
            guard
                let name = raw["name"] as? String,
                let imageName = raw["imageName"] as? String,
                let campaign = raw["campaign"] as? String,
                let budget = raw["budget"] as? String,
                let deliverables = raw["deliverables"] as? String,
                let pitch = raw["pitch"] as? String
            else {
                return nil
            }
            return .brand(
                BrandCard(
                    key: cardKey,
                    name: name,
                    imageName: imageName,
                    campaign: campaign,
                    budget: budget,
                    deliverables: deliverables,
                    pitch: pitch
                )
            )
        case "creator":
            guard
                let handle = raw["handle"] as? String,
                let imageName = raw["imageName"] as? String,
                let niche = raw["niche"] as? String,
                let followers = raw["followers"] as? String,
                let engagementRate = raw["engagementRate"] as? String,
                let pitch = raw["pitch"] as? String
            else {
                return nil
            }
            return .creator(
                CreatorCard(
                    key: cardKey,
                    handle: handle,
                    imageName: imageName,
                    niche: niche,
                    followers: followers,
                    engagementRate: engagementRate,
                    pitch: pitch
                )
            )
        default:
            return nil
        }
    }
}

private extension SwipeAction {
    var remoteValue: String {
        switch self {
        case .skip:
            return "skip"
        case .save:
            return "save"
        case .match:
            return "match"
        }
    }
}
