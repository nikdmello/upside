import Foundation

enum SwipeAction {
    case skip
    case save
    case match
}

enum DealStatus: String, Equatable, Codable {
    case draft
    case sent
    case accepted
    case declined

    var label: String {
        switch self {
        case .draft: return "Draft"
        case .sent: return "Sent"
        case .accepted: return "Accepted"
        case .declined: return "Declined"
        }
    }
}

struct DealProposal: Identifiable, Equatable, Codable {
    let id: UUID
    var budget: String
    var deliverables: String
    var timeline: String
    var notes: String
    var status: DealStatus
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        budget: String,
        deliverables: String,
        timeline: String,
        notes: String,
        status: DealStatus = .sent,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.budget = budget
        self.deliverables = deliverables
        self.timeline = timeline
        self.notes = notes
        self.status = status
        self.updatedAt = updatedAt
    }
}

struct PeerProfileSummary: Equatable, Codable {
    var headline: String
    var metricLine: String
    var about: String
    var tags: [String]
    var location: String
}

struct HomeFilters: Equatable, Codable {
    var minimumBrandBudget: Int? = nil
    var brandCampaignTags: Set<String> = []
    var minimumCreatorFollowers: Int? = nil
    var minimumCreatorEngagementRate: Double? = nil
    var creatorNicheTags: Set<String> = []

    private enum CodingKeys: String, CodingKey {
        case minimumBrandBudget
        case brandCampaignTags
        case minimumCreatorFollowers
        case minimumCreatorEngagementRate
        case creatorNicheTags
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        minimumBrandBudget = try container.decodeIfPresent(Int.self, forKey: .minimumBrandBudget)
        brandCampaignTags = try container.decodeIfPresent(Set<String>.self, forKey: .brandCampaignTags) ?? []
        minimumCreatorFollowers = try container.decodeIfPresent(Int.self, forKey: .minimumCreatorFollowers)
        minimumCreatorEngagementRate = try container.decodeIfPresent(Double.self, forKey: .minimumCreatorEngagementRate)
        creatorNicheTags = try container.decodeIfPresent(Set<String>.self, forKey: .creatorNicheTags) ?? []
    }

    func activeCount(for role: UserRole) -> Int {
        switch role {
        case .creator:
            var count = 0
            if minimumBrandBudget != nil { count += 1 }
            if !brandCampaignTags.isEmpty { count += 1 }
            return count
        case .brand:
            var count = 0
            if minimumCreatorFollowers != nil { count += 1 }
            if minimumCreatorEngagementRate != nil { count += 1 }
            if !creatorNicheTags.isEmpty { count += 1 }
            return count
        }
    }
}

struct HomeProfileDraft: Equatable, Codable {
    var displayName: String
    var headline: String
    var bio: String
    var location: String
    var email: String
    var websiteOrHandle: String

    private enum CodingKeys: String, CodingKey {
        case displayName
        case headline
        case bio
        case location
        case email
        case websiteOrHandle
    }

    init(
        displayName: String,
        headline: String,
        bio: String,
        location: String,
        email: String,
        websiteOrHandle: String
    ) {
        self.displayName = displayName
        self.headline = headline
        self.bio = bio
        self.location = location
        self.email = email
        self.websiteOrHandle = websiteOrHandle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        headline = try container.decodeIfPresent(String.self, forKey: .headline) ?? ""
        bio = try container.decodeIfPresent(String.self, forKey: .bio) ?? ""
        location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        websiteOrHandle = try container.decodeIfPresent(String.self, forKey: .websiteOrHandle) ?? ""
    }

    var initials: String {
        let letters = displayName
            .split(separator: " ")
            .compactMap { $0.first }
            .prefix(2)
        let result = String(letters).uppercased()
        return result.isEmpty ? "U" : result
    }

    static func mock(for role: UserRole) -> HomeProfileDraft {
        switch role {
        case .creator:
            return HomeProfileDraft(
                displayName: "Nikhil D'Mello",
                headline: "Creator • Tech",
                bio: "Short-form creator focused on clean visuals and storytelling.",
                location: "San Francisco, CA",
                email: "nikhil@upside.app",
                websiteOrHandle: "@nikhilcreates"
            )
        case .brand:
            return HomeProfileDraft(
                displayName: "Upside Demo",
                headline: "Brand • Growth Team",
                bio: "Performance-led brand team running creator partnerships across launch and evergreen campaigns.",
                location: "New York, NY",
                email: "partnerships@upside.app",
                websiteOrHandle: "upside.app"
            )
        }
    }
}

enum MessageSender: String, Equatable, Codable {
    case me
    case peer
    case system
}

struct ChatMessage: Identifiable, Equatable, Codable {
    let id: UUID
    let text: String
    let sender: MessageSender
    let timestamp: Date

    init(
        id: UUID = UUID(),
        text: String,
        sender: MessageSender,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.sender = sender
        self.timestamp = timestamp
    }
}

struct Conversation: Identifiable, Equatable, Codable {
    let id: UUID
    let peerKey: String
    let title: String
    let subtitle: String
    let avatarImageName: String
    let isBrand: Bool
    let needsLightAvatarBackground: Bool
    var unreadCount: Int
    var peerProfile: PeerProfileSummary
    var deal: DealProposal?
    var messages: [ChatMessage]
    var lastUpdatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case peerKey
        case title
        case subtitle
        case avatarImageName
        case isBrand
        case needsLightAvatarBackground
        case unreadCount
        case peerProfile
        case deal
        case messages
        case lastUpdatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        peerKey = try container.decodeIfPresent(String.self, forKey: .peerKey) ?? "peer-\(id.uuidString)"
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Conversation"
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        avatarImageName = try container.decodeIfPresent(String.self, forKey: .avatarImageName) ?? ""
        isBrand = try container.decodeIfPresent(Bool.self, forKey: .isBrand) ?? false
        needsLightAvatarBackground = try container.decodeIfPresent(Bool.self, forKey: .needsLightAvatarBackground) ?? false
        unreadCount = try container.decodeIfPresent(Int.self, forKey: .unreadCount) ?? 0
        peerProfile = try container.decodeIfPresent(PeerProfileSummary.self, forKey: .peerProfile) ?? PeerProfileSummary(
            headline: "",
            metricLine: "",
            about: "",
            tags: [],
            location: ""
        )
        deal = try container.decodeIfPresent(DealProposal.self, forKey: .deal)
        messages = try container.decodeIfPresent([ChatMessage].self, forKey: .messages) ?? []
        lastUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .lastUpdatedAt) ?? Date()
    }

    init(
        id: UUID = UUID(),
        peerKey: String,
        title: String,
        subtitle: String,
        avatarImageName: String,
        isBrand: Bool,
        needsLightAvatarBackground: Bool = false,
        unreadCount: Int = 0,
        peerProfile: PeerProfileSummary,
        deal: DealProposal? = nil,
        messages: [ChatMessage],
        lastUpdatedAt: Date = Date()
    ) {
        self.id = id
        self.peerKey = peerKey
        self.title = title
        self.subtitle = subtitle
        self.avatarImageName = avatarImageName
        self.isBrand = isBrand
        self.needsLightAvatarBackground = needsLightAvatarBackground
        self.unreadCount = unreadCount
        self.peerProfile = peerProfile
        self.deal = deal
        self.messages = messages
        self.lastUpdatedAt = lastUpdatedAt
    }

    var lastMessagePreview: String {
        messages.last?.text ?? "New match"
    }
}

struct BrandCard: Identifiable, Equatable {
    let id: UUID
    let key: String
    let name: String
    let imageName: String
    let campaign: String
    let budget: String
    let deliverables: String
    let pitch: String

    init(
        id: UUID = UUID(),
        key: String? = nil,
        name: String,
        imageName: String,
        campaign: String,
        budget: String,
        deliverables: String,
        pitch: String
    ) {
        self.id = id
        self.name = name
        self.imageName = imageName
        self.campaign = campaign
        self.budget = budget
        self.deliverables = deliverables
        self.pitch = pitch
        self.key = key ?? "brand-\(name.lowercased())"
    }
}

struct CreatorCard: Identifiable, Equatable {
    let id: UUID
    let key: String
    let handle: String
    let imageName: String
    let niche: String
    let followers: String
    let engagementRate: String
    let pitch: String

    init(
        id: UUID = UUID(),
        key: String? = nil,
        handle: String,
        imageName: String,
        niche: String,
        followers: String,
        engagementRate: String,
        pitch: String
    ) {
        self.id = id
        self.handle = handle
        self.imageName = imageName
        self.niche = niche
        self.followers = followers
        self.engagementRate = engagementRate
        self.pitch = pitch
        self.key = key ?? "creator-\(handle.lowercased())"
    }
}

enum HomeCard: Identifiable, Equatable {
    case brand(BrandCard)
    case creator(CreatorCard)

    var id: UUID {
        switch self {
        case .brand(let card): return card.id
        case .creator(let card): return card.id
        }
    }
}
