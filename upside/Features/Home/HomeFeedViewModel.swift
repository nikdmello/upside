import SwiftUI
import Combine

enum HomeSyncState: Equatable {
    case disabled
    case syncing
    case synced(Date)
    case failed(String)

    var isSyncing: Bool {
        if case .syncing = self { return true }
        return false
    }
}

final class HomeFeedViewModel: ObservableObject {
    let userRole: UserRole

    @Published var cards: [HomeCard]
    @Published var savedCards: [HomeCard] = []
    @Published var conversations: [Conversation]
    @Published var filters = HomeFilters()
    @Published var profile: HomeProfileDraft
    @Published var showMatch = false
    @Published var lastAction: SwipeAction?
    @Published var latestMatchConversationID: UUID?
    @Published private(set) var canUndoSkip = false
    @Published private(set) var syncState: HomeSyncState = .disabled
    @Published private(set) var requiresReauthentication = false
    @Published private(set) var reauthenticationMessage: String?

    private var allCards: [HomeCard]
    private let dataStore: any HomeDataStore
    private let remoteSync: (any HomeRemoteSyncing)?
    private let remoteFeed: (any HomeRemoteFeedServing)?
    private var swipedCardKeys: Set<String> = []
    private var lastSkippedCardKey: String?
    private var lastPersistedSnapshot: HomePersistenceSnapshot?
    private var pendingSyncTask: Task<Void, Never>?

    init(
        userRole: UserRole,
        dataStore: any HomeDataStore = HomePersistenceStore(),
        remoteSync: (any HomeRemoteSyncing)? = HomeRemoteSyncService.makeDefault(),
        remoteFeed: (any HomeRemoteFeedServing)? = HomeRemoteFeedService.makeDefault()
    ) {
        self.userRole = userRole
        self.dataStore = dataStore
        self.remoteSync = remoteSync
        self.remoteFeed = remoteFeed
        self.allCards = HomeFeedViewModel.mockCards(for: userRole)
        self.cards = allCards
        self.conversations = HomeFeedViewModel.mockConversations(for: userRole)
        self.profile = HomeProfileDraft.mock(for: userRole)
        loadPersistedState()
        self.cards = filteredCards()

        if remoteFeed != nil {
            loadRemoteFeed()
        }

        if remoteSync != nil {
            pullRemoteSnapshot()
        }
    }

    var currentCard: HomeCard? {
        cards.first
    }

    deinit {
        pendingSyncTask?.cancel()
    }

    func refreshRemoteState() {
        pullRemoteSnapshot()
    }

    func completeReauthentication() {
        requiresReauthentication = false
        reauthenticationMessage = nil
        loadRemoteFeed()
        pullRemoteSnapshot()
    }

    #if DEBUG
    func refreshRemoteStateForTesting() {
        refreshRemoteState()
    }

    func pushRemoteStateForTesting() {
        guard let snapshot = lastPersistedSnapshot else { return }
        scheduleRemotePush(with: snapshot)
    }
    #endif

    func swipe(_ action: SwipeAction) {
        guard let activeCard = currentCard else { return }
        lastAction = action

        if action == .save {
            saveCardToShortlist(activeCard)
        }

        if action == .skip {
            let skippedCard = activeCard
            lastSkippedCardKey = cardKey(for: skippedCard)
            canUndoSkip = true
        } else {
            lastSkippedCardKey = nil
            canUndoSkip = false
        }

        if action == .match {
            let matchedCard = activeCard
            latestMatchConversationID = upsertConversation(for: matchedCard)
            showMatch = true
        }

        removeTopCard(activeCard)
        recordRemoteSwipe(for: activeCard, action: action)
    }

    func unsaveCard(_ card: HomeCard) {
        guard removeFromSaved(card) else { return }
        swipedCardKeys.remove(cardKey(for: card))
        cards = filteredCards()
        persistState()
    }

    func skipSavedCard(_ card: HomeCard) {
        guard removeFromSaved(card) else { return }
        swipedCardKeys.insert(cardKey(for: card))
        cards = filteredCards()
        persistState()
        recordRemoteSwipe(for: card, action: .skip)
    }

    func matchSavedCard(_ card: HomeCard) {
        guard removeFromSaved(card) else { return }
        swipedCardKeys.insert(cardKey(for: card))
        latestMatchConversationID = upsertConversation(for: card)
        showMatch = true
        cards = filteredCards()
        persistState()
        recordRemoteSwipe(for: card, action: .match)
    }

    @discardableResult
    func undoLastSkip() -> Bool {
        guard let key = lastSkippedCardKey else { return false }
        guard swipedCardKeys.contains(key) else { return false }

        swipedCardKeys.remove(key)
        cards = filteredCards()

        if let index = cards.firstIndex(where: { cardKey(for: $0) == key }) {
            let card = cards.remove(at: index)
            cards.insert(card, at: 0)
        }

        lastSkippedCardKey = nil
        lastAction = nil
        canUndoSkip = false
        persistState()
        return true
    }

    func markConversationRead(_ conversationID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[index].unreadCount = 0
        persistState()
    }

    func sendMessage(_ text: String, in conversationID: UUID) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }

        let outgoing = ChatMessage(text: trimmed, sender: .me)
        conversations[index].messages.append(outgoing)
        conversations[index].lastUpdatedAt = outgoing.timestamp
        bringConversationToTop(at: index)
        persistState()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.appendAutoReply(in: conversationID)
        }
    }

    func submitDeal(
        in conversationID: UUID,
        budget: String,
        deliverables: String,
        timeline: String,
        notes: String
    ) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }

        let proposal = DealProposal(
            id: conversations[index].deal?.id ?? UUID(),
            budget: budget,
            deliverables: deliverables,
            timeline: timeline,
            notes: notes,
            status: .sent
        )

        conversations[index].deal = proposal
        conversations[index].lastUpdatedAt = proposal.updatedAt
        conversations[index].messages.append(
            ChatMessage(
                text: "Proposal sent: \(budget) • \(deliverables) • \(timeline)",
                sender: .system,
                timestamp: proposal.updatedAt
            )
        )
        bringConversationToTop(at: index)
        persistState()
    }

    func saveDealDraft(
        in conversationID: UUID,
        budget: String,
        deliverables: String,
        timeline: String,
        notes: String
    ) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }

        let proposal = DealProposal(
            id: conversations[index].deal?.id ?? UUID(),
            budget: budget,
            deliverables: deliverables,
            timeline: timeline,
            notes: notes,
            status: .draft
        )

        conversations[index].deal = proposal
        conversations[index].lastUpdatedAt = proposal.updatedAt
        conversations[index].messages.append(
            ChatMessage(
                text: "Draft proposal saved.",
                sender: .system,
                timestamp: proposal.updatedAt
            )
        )
        bringConversationToTop(at: index)
        persistState()
    }

    func sendDraftDeal(in conversationID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        guard var deal = conversations[index].deal else { return }
        guard deal.status != .sent else { return }

        deal.status = .sent
        deal.updatedAt = Date()
        conversations[index].deal = deal
        conversations[index].lastUpdatedAt = deal.updatedAt
        conversations[index].messages.append(
            ChatMessage(
                text: "Proposal sent.",
                sender: .system,
                timestamp: deal.updatedAt
            )
        )
        bringConversationToTop(at: index)
        persistState()
    }

    func updateDealStatus(_ status: DealStatus, in conversationID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        guard var existingDeal = conversations[index].deal else { return }

        existingDeal.status = status
        existingDeal.updatedAt = Date()
        conversations[index].deal = existingDeal
        conversations[index].lastUpdatedAt = existingDeal.updatedAt
        conversations[index].messages.append(
            ChatMessage(
                text: "Proposal \(status.label.lowercased()).",
                sender: .system,
                timestamp: existingDeal.updatedAt
            )
        )
        bringConversationToTop(at: index)
        persistState()
    }

    func applyFilters(_ updatedFilters: HomeFilters) {
        filters = updatedFilters
        cards = filteredCards()
        persistState()
    }

    func resetFilters() {
        filters = HomeFilters()
        cards = filteredCards()
        persistState()
    }

    func updateProfile(_ updatedProfile: HomeProfileDraft) {
        profile = updatedProfile
        persistState()
    }

    func resetMatchDeckForTesting() {
        swipedCardKeys.removeAll()
        savedCards.removeAll()
        lastSkippedCardKey = nil
        canUndoSkip = false
        latestMatchConversationID = nil
        showMatch = false
        cards = filteredCards()
        persistState()
        clearRemoteSwipeHistoryForTesting()
    }

    func resetHomeDataForTesting() {
        dataStore.clear(role: userRole)
        filters = HomeFilters()
        profile = HomeProfileDraft.mock(for: userRole)
        conversations = HomeFeedViewModel.mockConversations(for: userRole)
        swipedCardKeys.removeAll()
        savedCards.removeAll()
        lastSkippedCardKey = nil
        canUndoSkip = false
        latestMatchConversationID = nil
        showMatch = false
        cards = filteredCards()
        persistState()
        clearRemoteSwipeHistoryForTesting()
    }

    private func removeTopCard(_ topCard: HomeCard) {
        swipedCardKeys.insert(cardKey(for: topCard))
        cards = filteredCards()
        persistState()
    }

    private func upsertConversation(for card: HomeCard) -> UUID {
        let draftConversation = conversationForMatch(from: card)

        if let index = conversations.firstIndex(where: { $0.peerKey == draftConversation.peerKey }) {
            let systemMessage = ChatMessage(
                text: "You matched again. Want to line up details for this campaign?",
                sender: .system
            )
            conversations[index].messages.append(systemMessage)
            conversations[index].lastUpdatedAt = systemMessage.timestamp
            conversations[index].unreadCount += 1
            bringConversationToTop(at: index)
            return conversations[index].id
        }

        conversations.insert(draftConversation, at: 0)
        return draftConversation.id
    }

    private func appendAutoReply(in conversationID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        let reply = ChatMessage(
            text: "Perfect, I'm interested. Can you share timeline and deliverables?",
            sender: .peer
        )
        conversations[index].messages.append(reply)
        conversations[index].lastUpdatedAt = reply.timestamp
        conversations[index].unreadCount += 1
        bringConversationToTop(at: index)
        persistState()
    }

    private func conversationForMatch(from card: HomeCard) -> Conversation {
        switch card {
        case .brand(let brand):
            let intro = ChatMessage(
                text: "Excited to connect. We'd love to brief you on this campaign.",
                sender: .peer
            )
            return Conversation(
                peerKey: "brand-\(brand.name.lowercased())",
                title: brand.name,
                subtitle: brand.campaign,
                avatarImageName: brand.imageName,
                isBrand: true,
                needsLightAvatarBackground: ["Sephora", "Allbirds", "Apple", "Nike"].contains(brand.name),
                unreadCount: 1,
                peerProfile: PeerProfileSummary(
                    headline: "Brand opportunity",
                    metricLine: "\(brand.budget) • \(brand.deliverables)",
                    about: brand.pitch,
                    tags: campaignTags(from: brand.campaign),
                    location: "United States"
                ),
                messages: [intro],
                lastUpdatedAt: intro.timestamp
            )
        case .creator(let creator):
            let intro = ChatMessage(
                text: "Thanks for the match. Happy to discuss content ideas and rates.",
                sender: .peer
            )
            return Conversation(
                peerKey: "creator-\(creator.handle.lowercased())",
                title: creator.handle,
                subtitle: creator.niche,
                avatarImageName: creator.imageName,
                isBrand: false,
                peerProfile: PeerProfileSummary(
                    headline: creator.niche,
                    metricLine: "\(creator.followers) followers • \(creator.engagementRate)",
                    about: creator.pitch,
                    tags: creator.niche.components(separatedBy: "•").map { $0.trimmingCharacters(in: .whitespaces) },
                    location: "United States"
                ),
                messages: [intro],
                lastUpdatedAt: intro.timestamp
            )
        }
    }

    private func bringConversationToTop(at index: Int) {
        guard index < conversations.count else { return }
        let conversation = conversations.remove(at: index)
        conversations.insert(conversation, at: 0)
    }

    private func campaignTags(from campaign: String) -> [String] {
        let normalized = campaign.lowercased()
        var tags: [String] = []
        if normalized.contains("ugc") { tags.append("UGC") }
        if normalized.contains("launch") { tags.append("Launch") }
        if normalized.contains("fitness") { tags.append("Fitness") }
        if normalized.contains("story") { tags.append("Stories") }
        if tags.isEmpty { tags.append("Partnership") }
        return tags
    }

    private func filteredCards() -> [HomeCard] {
        allCards.filter { card in
            guard !swipedCardKeys.contains(cardKey(for: card)) else { return false }
            return cardMatchesFilters(card)
        }
    }

    private func cardKey(for card: HomeCard) -> String {
        switch card {
        case .brand(let brand):
            return brand.key
        case .creator(let creator):
            return creator.key
        }
    }

    private func loadRemoteFeed() {
        guard let remoteFeed else { return }

        Task { [weak self] in
            guard let self else { return }
            do {
                let fetched = try await remoteFeed.fetchCards(role: self.userRole, limit: 100, offset: 0)
                guard !fetched.isEmpty else { return }
                await MainActor.run {
                    self.applyRemoteFeedCards(fetched)
                }
            } catch {
                if await self.handleUnauthorizedErrorIfNeeded(error) {
                    return
                }
                // Keep local mock fallback if feed endpoint is unavailable.
            }
        }
    }

    private func applyRemoteFeedCards(_ fetchedCards: [HomeCard]) {
        allCards = fetchedCards

        let savedKeys = Set(lastPersistedSnapshot?.savedCardKeys ?? savedCards.map { cardKey(for: $0) })
        savedCards = fetchedCards.filter { savedKeys.contains(cardKey(for: $0)) }
        cards = filteredCards()
    }

    private func loadPersistedState() {
        guard let snapshot = dataStore.load(role: userRole) else { return }
        filters = snapshot.filters
        profile = snapshot.profile
        conversations = snapshot.conversations
        swipedCardKeys = Set(snapshot.swipedCardKeys)
        savedCards = snapshot.savedCardKeys.compactMap(card(forKey:))
        for card in savedCards {
            swipedCardKeys.insert(cardKey(for: card))
        }
        lastPersistedSnapshot = snapshot
    }

    private func persistState(syncRemote: Bool = true, timestamp: Date = Date()) {
        let snapshot = HomePersistenceSnapshot(
            lastUpdatedAt: timestamp,
            filters: filters,
            profile: profile,
            conversations: conversations,
            swipedCardKeys: Array(swipedCardKeys),
            savedCardKeys: savedCards.map(cardKey(for:))
        )
        dataStore.save(snapshot, role: userRole)
        lastPersistedSnapshot = snapshot

        if syncRemote {
            scheduleRemotePush(with: snapshot)
        }
    }

    private func pullRemoteSnapshot() {
        guard let remoteSync else {
            syncState = .disabled
            return
        }

        Task { [weak self] in
            guard let self else { return }
            await MainActor.run {
                self.syncState = .syncing
            }

            do {
                let remoteSnapshot = try await self.pullRemoteSnapshotWithRetry(remoteSync: remoteSync)
                await MainActor.run {
                    if let remoteSnapshot {
                        self.applyRemoteSnapshotIfNewer(remoteSnapshot)
                    } else if let localSnapshot = self.lastPersistedSnapshot {
                        self.scheduleRemotePush(with: localSnapshot)
                    }
                    self.syncState = .synced(Date())
                }
            } catch {
                if error is CancellationError {
                    return
                }
                if await self.handleUnauthorizedErrorIfNeeded(error) {
                    return
                }
                await MainActor.run {
                    self.syncState = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func applyRemoteSnapshotIfNewer(_ remoteSnapshot: HomePersistenceSnapshot) {
        let localTimestamp = lastPersistedSnapshot?.lastUpdatedAt ?? .distantPast
        guard remoteSnapshot.lastUpdatedAt > localTimestamp else { return }

        filters = remoteSnapshot.filters
        profile = remoteSnapshot.profile
        conversations = remoteSnapshot.conversations
        swipedCardKeys = Set(remoteSnapshot.swipedCardKeys)
        savedCards = remoteSnapshot.savedCardKeys.compactMap(card(forKey:))
        for card in savedCards {
            swipedCardKeys.insert(cardKey(for: card))
        }
        cards = filteredCards()
        lastSkippedCardKey = nil
        canUndoSkip = false

        persistState(syncRemote: false, timestamp: remoteSnapshot.lastUpdatedAt)
    }

    private func scheduleRemotePush(with snapshot: HomePersistenceSnapshot) {
        guard let remoteSync else {
            syncState = .disabled
            return
        }

        pendingSyncTask?.cancel()
        pendingSyncTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await Task.sleep(nanoseconds: 600_000_000)
            } catch {
                return
            }

            await MainActor.run {
                self.syncState = .syncing
            }

            do {
                try await self.pushRemoteSnapshotWithRetry(snapshot, remoteSync: remoteSync)
                await MainActor.run {
                    self.syncState = .synced(Date())
                }
            } catch {
                if error is CancellationError {
                    return
                }

                if let syncError = error as? HomeRemoteSyncError {
                    switch syncError {
                    case .conflict(let conflictSnapshot):
                        let resolvedSnapshot: HomePersistenceSnapshot?
                        if let conflictSnapshot {
                            resolvedSnapshot = conflictSnapshot
                        } else {
                            resolvedSnapshot = try? await self.pullRemoteSnapshotWithRetry(remoteSync: remoteSync)
                        }
                        await MainActor.run {
                            if let resolvedSnapshot {
                                self.applyRemoteSnapshotIfNewer(resolvedSnapshot)
                            }
                            self.syncState = .synced(Date())
                        }
                        return
                    default:
                        break
                    }
                }

                if await self.handleUnauthorizedErrorIfNeeded(error) {
                    return
                }

                await MainActor.run {
                    self.syncState = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func pullRemoteSnapshotWithRetry(remoteSync: any HomeRemoteSyncing) async throws -> HomePersistenceSnapshot? {
        var attempts = 0
        let maxAttempts = 3

        while true {
            do {
                return try await remoteSync.pull(role: userRole)
            } catch {
                attempts += 1
                guard shouldRetrySyncError(error), attempts < maxAttempts else {
                    throw error
                }
                try await Task.sleep(nanoseconds: retryDelayNanos(forAttempt: attempts))
            }
        }
    }

    private func pushRemoteSnapshotWithRetry(
        _ snapshot: HomePersistenceSnapshot,
        remoteSync: any HomeRemoteSyncing
    ) async throws {
        var attempts = 0
        let maxAttempts = 3
        let idempotencyKey = makeRemoteSyncIdempotencyKey(for: snapshot)

        while true {
            do {
                try await remoteSync.push(snapshot, role: userRole, idempotencyKey: idempotencyKey)
                return
            } catch {
                if let syncError = error as? HomeRemoteSyncError, case .conflict = syncError {
                    throw syncError
                }

                attempts += 1
                guard shouldRetrySyncError(error), attempts < maxAttempts else {
                    throw error
                }
                try await Task.sleep(nanoseconds: retryDelayNanos(forAttempt: attempts))
            }
        }
    }

    private func shouldRetrySyncError(_ error: Error) -> Bool {
        if error is CancellationError {
            return false
        }

        if error is URLError {
            return true
        }

        if let syncError = error as? HomeRemoteSyncError {
            switch syncError {
            case .unexpectedStatusCode(let code):
                return code == 429 || (500...599).contains(code)
            case .conflict:
                return false
            default:
                return false
            }
        }

        return false
    }

    private func retryDelayNanos(forAttempt attempt: Int) -> UInt64 {
        // 0.4s, 0.8s, 1.6s...
        let seconds = pow(2.0, Double(max(0, attempt - 1))) * 0.4
        return UInt64(seconds * 1_000_000_000)
    }

    private func makeRemoteSyncIdempotencyKey(for snapshot: HomePersistenceSnapshot) -> String {
        let millis = Int(snapshot.lastUpdatedAt.timeIntervalSince1970 * 1_000)
        return "home-state-\(userRole.rawValue)-\(millis)-\(UUID().uuidString.lowercased())"
    }

    private func saveCardToShortlist(_ card: HomeCard) {
        let key = cardKey(for: card)
        guard !savedCards.contains(where: { cardKey(for: $0) == key }) else { return }
        savedCards.insert(card, at: 0)
    }

    private func recordRemoteSwipe(for card: HomeCard, action: SwipeAction) {
        guard let remoteFeed else { return }
        let key = cardKey(for: card)
        Task {
            do {
                try await remoteFeed.recordSwipe(role: userRole, cardKey: key, action: action)
            } catch {
                if await self.handleUnauthorizedErrorIfNeeded(error) {
                    return
                }
                // Best-effort telemetry/event sync; local UX remains responsive.
            }
        }
    }

    private func clearRemoteSwipeHistoryForTesting() {
        guard let remoteFeed else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await remoteFeed.clearSwipeHistory(role: self.userRole)
            } catch {
                if await self.handleUnauthorizedErrorIfNeeded(error) {
                    return
                }
                return
            }
            await MainActor.run {
                self.loadRemoteFeed()
            }
        }
    }

    private func removeFromSaved(_ card: HomeCard) -> Bool {
        let key = cardKey(for: card)
        guard let index = savedCards.firstIndex(where: { cardKey(for: $0) == key }) else {
            return false
        }
        savedCards.remove(at: index)
        return true
    }

    private func card(forKey key: String) -> HomeCard? {
        allCards.first { cardKey(for: $0) == key }
    }

    private func handleUnauthorizedErrorIfNeeded(_ error: Error) async -> Bool {
        guard isUnauthorizedError(error) else { return false }

        pendingSyncTask?.cancel()
        await BackendAuthSession.shared.clear()
        await MainActor.run {
            self.requiresReauthentication = true
            self.reauthenticationMessage = "Your session expired. Sign in again to reconnect to Upside."
            self.syncState = .failed("Session expired. Sign in again.")
        }
        return true
    }

    private func isUnauthorizedError(_ error: Error) -> Bool {
        if let syncError = error as? HomeRemoteSyncError, case .unauthorized = syncError {
            return true
        }

        if let feedError = error as? HomeRemoteFeedError, case .unauthorized = feedError {
            return true
        }

        return false
    }

    private func cardMatchesFilters(_ card: HomeCard) -> Bool {
        switch userRole {
        case .creator:
            guard case .brand(let brandCard) = card else { return false }

            if let minimumBudget = filters.minimumBrandBudget {
                let maxBudget = maxBudgetValue(from: brandCard.budget)
                if maxBudget < minimumBudget { return false }
            }

            if !filters.brandCampaignTags.isEmpty {
                let text = "\(brandCard.campaign) \(brandCard.pitch) \(brandCard.deliverables)".lowercased()
                let matchesTag = filters.brandCampaignTags.contains { tag in
                    text.contains(tag.lowercased())
                }
                if !matchesTag { return false }
            }
            return true

        case .brand:
            guard case .creator(let creatorCard) = card else { return false }

            if let minimumFollowers = filters.minimumCreatorFollowers {
                if followerCountValue(from: creatorCard.followers) < minimumFollowers { return false }
            }

            if let minimumEngagement = filters.minimumCreatorEngagementRate {
                if engagementRateValue(from: creatorCard.engagementRate) < minimumEngagement { return false }
            }

            if !filters.creatorNicheTags.isEmpty {
                let niche = creatorCard.niche.lowercased()
                let matchesNiche = filters.creatorNicheTags.contains { tag in
                    niche.contains(tag.lowercased())
                }
                if !matchesNiche { return false }
            }
            return true
        }
    }

    private func maxBudgetValue(from budgetText: String) -> Int {
        let values = numericValues(from: budgetText)
        return Int(values.max() ?? 0)
    }

    private func followerCountValue(from followersText: String) -> Int {
        let normalized = followersText.uppercased().replacingOccurrences(of: ",", with: "")
        let multiplier: Double
        if normalized.contains("M") {
            multiplier = 1_000_000
        } else if normalized.contains("K") {
            multiplier = 1_000
        } else {
            multiplier = 1
        }

        let numeric = numericValues(from: normalized).first ?? 0
        return Int(numeric * multiplier)
    }

    private func engagementRateValue(from engagementText: String) -> Double {
        numericValues(from: engagementText).first ?? 0
    }

    private func numericValues(from text: String) -> [Double] {
        text
            .split(whereSeparator: { !$0.isNumber && $0 != "." && $0 != "," })
            .compactMap {
                Double($0.replacingOccurrences(of: ",", with: ""))
            }
    }

    static func mockCards(for role: UserRole) -> [HomeCard] {
        switch role {
        case .creator:
            return [
                .brand(BrandCard(
                    name: "Nike",
                    imageName: "Brand_Nike",
                    campaign: "UGC Reels for new training line",
                    budget: "AED 500-AED 2,000",
                    deliverables: "2 Reels, 1 Story",
                    pitch: "Looking for fitness creators with high engagement."
                )),
                .brand(BrandCard(
                    name: "Sephora",
                    imageName: "Brand_Sephora",
                    campaign: "GRWM short-form series",
                    budget: "AED 300-AED 1,200",
                    deliverables: "3 Shorts, 1 Post",
                    pitch: "Beauty creators who love new drops and reviews."
                )),
                .brand(BrandCard(
                    name: "Allbirds",
                    imageName: "Brand_Allbirds",
                    campaign: "Lifestyle sneaker launch",
                    budget: "AED 400-AED 1,500",
                    deliverables: "2 Reels, 2 Stories",
                    pitch: "Eco-friendly lifestyle creators with clean aesthetic."
                )),
                .brand(BrandCard(
                    name: "Apple",
                    imageName: "Brand_Apple",
                    campaign: "Shot on iPhone stories",
                    budget: "AED 700-AED 2,500",
                    deliverables: "1 Reel, 2 Stories",
                    pitch: "Creators who can spotlight real-world camera use."
                )),
                .brand(BrandCard(
                    name: "Spotify",
                    imageName: "Brand_Spotify",
                    campaign: "Playlist launch collab",
                    budget: "AED 300-AED 900",
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

    static func mockConversations(for role: UserRole) -> [Conversation] {
        switch role {
        case .creator:
            let now = Date()
            return [
                Conversation(
                    peerKey: "brand-spotify",
                    title: "Spotify",
                    subtitle: "Playlist launch collab",
                    avatarImageName: "Brand_Spotify",
                    isBrand: true,
                    peerProfile: PeerProfileSummary(
                        headline: "Music platform",
                        metricLine: "AED 300-AED 900 • 1 Reel, 1 Story",
                        about: "Global streaming brand looking for creator-led playlist moments.",
                        tags: ["Music", "Launch", "Reels"],
                        location: "New York, NY"
                    ),
                    messages: [
                        ChatMessage(
                            text: "Loved your recent short-form clips. Interested in a launch collab?",
                            sender: .peer,
                            timestamp: now.addingTimeInterval(-3_300)
                        ),
                        ChatMessage(
                            text: "Yes, send over the campaign brief and timeline.",
                            sender: .me,
                            timestamp: now.addingTimeInterval(-3_100)
                        )
                    ],
                    lastUpdatedAt: now.addingTimeInterval(-3_100)
                ),
                Conversation(
                    peerKey: "brand-nike",
                    title: "Nike",
                    subtitle: "UGC Reels for new training line",
                    avatarImageName: "Brand_Nike",
                    isBrand: true,
                    needsLightAvatarBackground: true,
                    unreadCount: 1,
                    peerProfile: PeerProfileSummary(
                        headline: "Fitness campaign",
                        metricLine: "AED 500-AED 2,000 • 2 Reels, 1 Story",
                        about: "Performance-focused brand campaign for short-form UGC creators.",
                        tags: ["Fitness", "UGC", "Performance"],
                        location: "Portland, OR"
                    ),
                    deal: DealProposal(
                        budget: "AED 1,200",
                        deliverables: "2 Reels, 1 Story",
                        timeline: "10 days",
                        notes: "Need first draft in 4 days.",
                        status: .sent,
                        updatedAt: now.addingTimeInterval(-7_700)
                    ),
                    messages: [
                        ChatMessage(
                            text: "Can you share availability for next week?",
                            sender: .peer,
                            timestamp: now.addingTimeInterval(-7_800)
                        )
                    ],
                    lastUpdatedAt: now.addingTimeInterval(-7_800)
                )
            ]
        case .brand:
            let now = Date()
            return [
                Conversation(
                    peerKey: "creator-nikdmello",
                    title: "@nikdmello",
                    subtitle: "Tech • Product",
                    avatarImageName: "Creator_nikdmello",
                    isBrand: false,
                    peerProfile: PeerProfileSummary(
                        headline: "Tech • Product creator",
                        metricLine: "210K followers • 5.1% ER",
                        about: "Product-first creator focused on clear demos and conversion narrative.",
                        tags: ["Tech", "Product", "Short-form"],
                        location: "San Francisco, CA"
                    ),
                    messages: [
                        ChatMessage(
                            text: "Happy to shoot two demo reels. What's the posting window?",
                            sender: .peer,
                            timestamp: now.addingTimeInterval(-2_200)
                        ),
                        ChatMessage(
                            text: "Great. We can run this campaign next Thursday.",
                            sender: .me,
                            timestamp: now.addingTimeInterval(-2_000)
                        )
                    ],
                    lastUpdatedAt: now.addingTimeInterval(-2_000)
                ),
                Conversation(
                    peerKey: "creator-mikethurston",
                    title: "@mikethurston",
                    subtitle: "Fitness • Lifestyle",
                    avatarImageName: "Creator_mikethurston",
                    isBrand: false,
                    unreadCount: 1,
                    peerProfile: PeerProfileSummary(
                        headline: "Fitness • Lifestyle creator",
                        metricLine: "128K followers • 4.3% ER",
                        about: "Lifestyle creator producing high-energy training and routine content.",
                        tags: ["Fitness", "Lifestyle", "Reels"],
                        location: "Los Angeles, CA"
                    ),
                    messages: [
                        ChatMessage(
                            text: "Let's discuss bundle pricing for reels and stories.",
                            sender: .peer,
                            timestamp: now.addingTimeInterval(-6_300)
                        )
                    ],
                    lastUpdatedAt: now.addingTimeInterval(-6_300)
                )
            ]
        }
    }
}
