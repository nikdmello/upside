import Foundation

protocol HomeDataStore {
    func load(role: UserRole) -> HomePersistenceSnapshot?
    func save(_ snapshot: HomePersistenceSnapshot, role: UserRole)
    func clear(role: UserRole)
}

struct HomePersistenceSnapshot: Codable {
    var schemaVersion: Int
    var lastUpdatedAt: Date
    var filters: HomeFilters
    var profile: HomeProfileDraft
    var conversations: [Conversation]
    var swipedCardKeys: [String]
    var savedCardKeys: [String]

    init(
        schemaVersion: Int = 1,
        lastUpdatedAt: Date = Date(),
        filters: HomeFilters,
        profile: HomeProfileDraft,
        conversations: [Conversation],
        swipedCardKeys: [String],
        savedCardKeys: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.lastUpdatedAt = lastUpdatedAt
        self.filters = filters
        self.profile = profile
        self.conversations = conversations
        self.swipedCardKeys = swipedCardKeys
        self.savedCardKeys = savedCardKeys
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case lastUpdatedAt
        case filters
        case profile
        case conversations
        case swipedCardKeys
        case savedCardKeys
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        lastUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .lastUpdatedAt) ?? .distantPast
        filters = try container.decode(HomeFilters.self, forKey: .filters)
        profile = try container.decode(HomeProfileDraft.self, forKey: .profile)
        conversations = try container.decode([Conversation].self, forKey: .conversations)
        swipedCardKeys = try container.decode([String].self, forKey: .swipedCardKeys)
        savedCardKeys = try container.decodeIfPresent([String].self, forKey: .savedCardKeys) ?? []
    }
}

final class HomePersistenceStore: HomeDataStore {
    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        self.decoder = decoder
    }

    func load(role: UserRole) -> HomePersistenceSnapshot? {
        guard let data = defaults.data(forKey: key(for: role)) else { return nil }
        return try? decoder.decode(HomePersistenceSnapshot.self, from: data)
    }

    func save(_ snapshot: HomePersistenceSnapshot, role: UserRole) {
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: key(for: role))
    }

    func clear(role: UserRole) {
        defaults.removeObject(forKey: key(for: role))
    }

    private func key(for role: UserRole) -> String {
        "home.persistence.\(role.rawValue).v1"
    }
}
