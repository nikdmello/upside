import SwiftUI
import Combine

final class HomeFeedViewModel: ObservableObject {
    @Published var cards: [HomeCard]
    @Published var showMatch = false
    @Published var lastAction: SwipeAction?

    init(userRole: UserRole) {
        self.cards = HomeFeedViewModel.mockCards(for: userRole)
    }

    var currentCard: HomeCard? {
        cards.first
    }

    func swipe(_ action: SwipeAction) {
        lastAction = action

        if action == .match {
            showMatch = true
        }

        removeTopCard()
    }

    private func removeTopCard() {
        guard !cards.isEmpty else { return }
        cards.removeFirst()
    }

    static func mockCards(for role: UserRole) -> [HomeCard] {
        switch role {
        case .creator:
            return [
                .brand(BrandCard(
                    name: "Nike",
                    imageName: "Brand_Nike",
                    campaign: "UGC Reels for new training line",
                    budget: "$500–$2,000",
                    deliverables: "2 Reels, 1 Story",
                    pitch: "Looking for fitness creators with high engagement."
                )),
                .brand(BrandCard(
                    name: "Sephora",
                    imageName: "Brand_Sephora",
                    campaign: "GRWM short-form series",
                    budget: "$300–$1,200",
                    deliverables: "3 Shorts, 1 Post",
                    pitch: "Beauty creators who love new drops and reviews."
                )),
                .brand(BrandCard(
                    name: "Allbirds",
                    imageName: "Brand_Allbirds",
                    campaign: "Lifestyle sneaker launch",
                    budget: "$400–$1,500",
                    deliverables: "2 Reels, 2 Stories",
                    pitch: "Eco-friendly lifestyle creators with clean aesthetic."
                )),
                .brand(BrandCard(
                    name: "Apple",
                    imageName: "Brand_Apple",
                    campaign: "Shot on iPhone stories",
                    budget: "$700–$2,500",
                    deliverables: "1 Reel, 2 Stories",
                    pitch: "Creators who can spotlight real-world camera use."
                )),
                .brand(BrandCard(
                    name: "Spotify",
                    imageName: "Brand_Spotify",
                    campaign: "Playlist launch collab",
                    budget: "$300–$900",
                    deliverables: "1 Reel, 1 Story",
                    pitch: "Music creators with strong community engagement."
                ))
            ]
        case .brand:
            return [
                .creator(CreatorCard(
                    handle: "@nikdmello",
                    imageName: "Creator_nikdmello",
                    niche: "Tech • Product",
                    followers: "210K",
                    engagementRate: "5.1% ER",
                    pitch: "Product storytelling that drives intent."
                )),
                .creator(CreatorCard(
                    handle: "@abdulmurad_",
                    imageName: "Creator_abdulmurad_",
                    niche: "Fashion • Streetwear",
                    followers: "142K",
                    engagementRate: "4.8% ER",
                    pitch: "Clean aesthetic and strong conversion on drops."
                )),
                .creator(CreatorCard(
                    handle: "@jxshdxniells",
                    imageName: "Creator_jxshdxniells",
                    niche: "Culture • Lifestyle",
                    followers: "76K",
                    engagementRate: "3.6% ER",
                    pitch: "High-retention short-form with community pull."
                )),
                .creator(CreatorCard(
                    handle: "@srav.ya",
                    imageName: "Creator_srav.ya",
                    niche: "Travel • Lifestyle",
                    followers: "86K",
                    engagementRate: "3.9% ER",
                    pitch: "Authentic storytelling with premium brands."
                )),
                .creator(CreatorCard(
                    handle: "@mikethurston",
                    imageName: "Creator_mikethurston",
                    niche: "Fitness • Lifestyle",
                    followers: "128K",
                    engagementRate: "4.3% ER",
                    pitch: "Creates high-converting short-form with real energy."
                ))
            ]
        }
    }
}
