import Foundation

enum SwipeAction {
    case skip
    case save
    case match
}

struct BrandCard: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let imageName: String
    let campaign: String
    let budget: String
    let deliverables: String
    let pitch: String
}

struct CreatorCard: Identifiable, Equatable {
    let id = UUID()
    let handle: String
    let imageName: String
    let niche: String
    let followers: String
    let engagementRate: String
    let pitch: String
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
