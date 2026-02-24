import SwiftUI

struct HomeTabShellView: View {
    let userRole: UserRole

    @StateObject private var viewModel: HomeFeedViewModel
    @State private var selectedTab: HomeTab = .home
    @State private var initialInboxConversationID: UUID?

    init(userRole: UserRole) {
        self.userRole = userRole
        _viewModel = StateObject(wrappedValue: HomeFeedViewModel(userRole: userRole))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedTab) {
                HomeView(
                    userRole: userRole,
                    viewModel: viewModel,
                    onOpenInbox: { conversationID in
                        initialInboxConversationID = conversationID
                        selectedTab = .inbox
                    }
                )
                .tag(HomeTab.home)
                .tabItem {
                    Label("Home", systemImage: "flame.fill")
                }

                ChatStubView(
                    viewModel: viewModel,
                    initialConversationID: initialInboxConversationID,
                    onClose: {
                        selectedTab = .home
                    },
                    showsCloseButton: false
                )
                .tag(HomeTab.inbox)
                .tabItem {
                    Label("Inbox", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .badge(totalUnreadCount > 0 ? totalUnreadCount : 0)

                HomeProfileView(userRole: userRole, viewModel: viewModel)
                    .tag(HomeTab.profile)
                    .tabItem {
                        Label("You", systemImage: "person.crop.circle.fill")
                    }
            }
            .tint(.upsideGreen)
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onChange(of: selectedTab) { _, tab in
            if tab != .inbox {
                initialInboxConversationID = nil
            }
        }
    }

    private var totalUnreadCount: Int {
        viewModel.conversations.reduce(0) { $0 + $1.unreadCount }
    }
}

private enum HomeTab: Hashable {
    case home
    case inbox
    case profile
}

private struct HomeProfileView: View {
    let userRole: UserRole
    @ObservedObject var viewModel: HomeFeedViewModel

    @State private var showProfileEditor = false
    @State private var showPublicProfile = false
    @State private var showResetMatchDeckAlert = false
    @State private var showResetHomeDataAlert = false
    @State private var showTestingTools = false

    init(userRole: UserRole, viewModel: HomeFeedViewModel) {
        self.userRole = userRole
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color.black, Color.upsideGreen.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.upsideGreen.opacity(0.14), Color.clear],
                center: .topLeading,
                startRadius: 40,
                endRadius: 360
            )
            .ignoresSafeArea()
            .offset(x: -130, y: -120)
            .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 20) {
                    profileTopActions
                        .padding(.top, 8)

                    profileHeroCard

                    statsGrid

                    #if DEBUG
                    testingToolsSection
                    #endif
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showProfileEditor) {
            HomeProfileEditorSheet(
                role: userRole,
                initialProfile: viewModel.profile,
                onSave: { updated in
                    viewModel.updateProfile(updated)
                    showProfileEditor = false
                },
                onClose: {
                    showProfileEditor = false
                }
            )
            .presentationDetents([.large])
            .presentationBackground(.black)
        }
        .sheet(isPresented: $showPublicProfile) {
            HomePublicProfileSheet(
                userRole: userRole,
                profile: profile,
                closedDealsCount: closedDealsCount,
                activeDealsCount: activeDealsCount,
                matchCount: matchCount,
                onClose: { showPublicProfile = false }
            )
            .presentationDetents([.large])
            .presentationBackground(.black)
        }
        .alert("Reset match deck?", isPresented: $showResetMatchDeckAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                viewModel.resetMatchDeckForTesting()
            }
        } message: {
            Text("This restores all swipe cards so you can re-test matching.")
        }
        .alert("Reset all home data?", isPresented: $showResetHomeDataAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset All", role: .destructive) {
                viewModel.resetHomeDataForTesting()
            }
        } message: {
            Text("This clears filters, profile edits, conversations, and swipe progress for this role.")
        }
    }

    private var closedDealsCount: Int {
        viewModel.conversations.reduce(0) { partial, conversation in
            partial + ((conversation.deal?.status == .accepted) ? 1 : 0)
        }
    }

    private var activeDealsCount: Int {
        viewModel.conversations.reduce(0) { partial, conversation in
            guard let status = conversation.deal?.status else { return partial }
            return partial + ((status == .draft || status == .sent) ? 1 : 0)
        }
    }

    private var matchCount: Int {
        viewModel.conversations.count
    }

    private var acceptedDealsCount: Int {
        viewModel.conversations.reduce(0) { partial, conversation in
            partial + ((conversation.deal?.status == .accepted) ? 1 : 0)
        }
    }

    private var declinedDealsCount: Int {
        viewModel.conversations.reduce(0) { partial, conversation in
            partial + ((conversation.deal?.status == .declined) ? 1 : 0)
        }
    }

    private var acceptanceRateText: String {
        let reviewed = acceptedDealsCount + declinedDealsCount
        guard reviewed > 0 else { return "—" }
        let rate = (Double(acceptedDealsCount) / Double(reviewed)) * 100
        return "\(Int(rate.rounded()))%"
    }

    private var averageResponseTimeText: String {
        var intervals: [TimeInterval] = []

        for conversation in viewModel.conversations {
            let sortedMessages = conversation.messages.sorted { $0.timestamp < $1.timestamp }
            var pendingPeerTimestamp: Date?

            for message in sortedMessages {
                switch message.sender {
                case .peer:
                    pendingPeerTimestamp = message.timestamp
                case .me:
                    if let peerTimestamp = pendingPeerTimestamp, message.timestamp >= peerTimestamp {
                        intervals.append(message.timestamp.timeIntervalSince(peerTimestamp))
                        pendingPeerTimestamp = nil
                    }
                case .system:
                    continue
                }
            }
        }

        guard !intervals.isEmpty else { return "—" }
        let average = intervals.reduce(0, +) / Double(intervals.count)

        if average < 3600 {
            return "\(max(1, Int((average / 60).rounded())))m"
        } else if average < 86_400 {
            return "\(max(1, Int((average / 3600).rounded())))h"
        } else {
            return "\(max(1, Int((average / 86_400).rounded())))d"
        }
    }

    private var roleLabel: String {
        userRole == .creator ? "Creator" : "Brand"
    }

    private var profile: HomeProfileDraft {
        viewModel.profile
    }

    private var displayNameText: String {
        profile.displayName.isEmpty ? "Your Name" : profile.displayName
    }

    private var headlineText: String {
        profile.headline.isEmpty ? "\(roleLabel) on Upside" : profile.headline
    }

    private var locationText: String {
        profile.location.isEmpty ? "Location pending" : profile.location
    }

    private var stats: [ProfileStatMetric] {
        [
            ProfileStatMetric(title: "Deals Closed", value: "\(closedDealsCount)", subtitle: "completed", icon: "checkmark.seal.fill"),
            ProfileStatMetric(title: "Acceptance", value: acceptanceRateText, subtitle: "success rate", icon: "chart.line.uptrend.xyaxis"),
            ProfileStatMetric(title: "Avg Reply", value: averageResponseTimeText, subtitle: "response time", icon: "timer"),
            ProfileStatMetric(title: "Active Deals", value: "\(activeDealsCount)", subtitle: "in flight", icon: "bolt.fill")
        ]
    }

    private var profileHeroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 74, height: 74)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .overlay(
                        Text(profile.initials)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(displayNameText)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.88)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(headlineText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.76))
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 11, weight: .semibold))
                        Text(locationText)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundColor(.white.opacity(0.6))
                }

                Spacer(minLength: 0)

                Text(roleLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.upsideGreen)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.05), Color.upsideGreen.opacity(0.07)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 12)
    }

    private var profileTopActions: some View {
        HStack(spacing: 10) {
            Text("You")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Spacer(minLength: 0)

            topActionButton(
                systemImage: "eye",
                foreground: .white.opacity(0.88),
                background: Color.white.opacity(0.06),
                border: Color.white.opacity(0.16),
                accessibilityLabel: "View Public Profile"
            ) {
                showPublicProfile = true
            }

            topActionButton(
                systemImage: "square.and.pencil",
                foreground: .black,
                background: .upsideGreen,
                border: .upsideGreen,
                accessibilityLabel: "Edit Profile"
            ) {
                showProfileEditor = true
            }
        }
    }

    private func topActionButton(
        systemImage: String,
        foreground: Color,
        background: Color,
        border: Color,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(foreground)
                .frame(width: 38, height: 38)
                .background(background)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(border.opacity(0.9), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(stats) { stat in
                compactStatCard(stat: stat)
            }
        }
    }

    #if DEBUG
    private var testingToolsSection: some View {
        DisclosureGroup(isExpanded: $showTestingTools) {
            VStack(alignment: .leading, spacing: 10) {
                Button("Reset Match Deck") {
                    showResetMatchDeckAlert = true
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )

                Button("Reset All Home Data") {
                    showResetHomeDataAlert = true
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.red.opacity(0.95))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.red.opacity(0.42), lineWidth: 1)
                )
            }
            .padding(.top, 10)
        } label: {
            Text("Developer Tools")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.72))
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    #endif

    private func compactStatCard(stat: ProfileStatMetric) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: stat.icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.upsideGreen)
                .frame(width: 22, height: 22)
                .background(Color.upsideGreen.opacity(0.16))
                .clipShape(Circle())

            Text(stat.value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            Text(stat.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.78))

            Text(stat.subtitle.uppercased())
                .font(.system(size: 10, weight: .bold))
                .kerning(0.8)
                .foregroundColor(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: 6, x: 0, y: 4)
    }

}

private struct HomePublicProfileSheet: View {
    let userRole: UserRole
    let profile: HomeProfileDraft
    let closedDealsCount: Int
    let activeDealsCount: Int
    let matchCount: Int
    let onClose: () -> Void

    private var roleLabel: String {
        userRole == .creator ? "Creator" : "Brand"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.black, Color.black, Color.upsideGreen.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                RadialGradient(
                    colors: [Color.upsideGreen.opacity(0.14), Color.clear],
                    center: .topLeading,
                    startRadius: 20,
                    endRadius: 340
                )
                .ignoresSafeArea()
                .offset(x: -120, y: -120)
                .allowsHitTesting(false)

                ScrollView {
                    VStack(spacing: 14) {
                        publicHeroCard

                        if !profile.bio.isEmpty {
                            aboutCard
                        }

                        infoCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 26)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Public Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", action: onClose)
                        .foregroundColor(.white.opacity(0.82))
                }
            }
        }
    }

    private var displayNameText: String {
        profile.displayName.isEmpty ? "Upside User" : profile.displayName
    }

    private var headlineText: String {
        profile.headline.isEmpty ? "\(roleLabel) on Upside" : profile.headline
    }

    private var locationText: String {
        profile.location.isEmpty ? "Location pending" : profile.location
    }

    private var publicHeroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("PUBLIC PROFILE")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(0.7)
                    .foregroundColor(.white.opacity(0.62))

                Spacer()

                Text(roleLabel.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.upsideGreen)
                    .clipShape(Capsule())
            }

            HStack(spacing: 12) {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 66, height: 66)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .overlay(
                        Text(profile.initials)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayNameText)
                        .font(.system(size: 25, weight: .bold))
                        .foregroundColor(.white)
                    Text(headlineText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.78))
                        .lineLimit(2)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                publicTag("\(closedDealsCount) Closed")
                publicTag("\(activeDealsCount) Active")
                publicTag("\(matchCount) Matches")
            }

            Label(locationText, systemImage: "mappin.and.ellipse")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.62))
                .lineLimit(1)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.05), Color.upsideGreen.opacity(0.07)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.system(size: 12, weight: .bold))
                .kerning(0.6)
                .foregroundColor(.white.opacity(0.62))
                .textCase(.uppercase)

            Text(profile.bio)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.82))
                .lineSpacing(2)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var infoCard: some View {
        VStack(spacing: 8) {
            infoRow(
                icon: userRole == .creator ? "at" : "link",
                title: userRole == .creator ? "Handle" : "Website",
                value: profile.websiteOrHandle.isEmpty ? "Not provided" : profile.websiteOrHandle
            )
            infoRow(
                icon: "envelope",
                title: "Email",
                value: profile.email.isEmpty ? "Not provided" : profile.email
            )
            infoRow(
                icon: "mappin.and.ellipse",
                title: "Location",
                value: locationText
            )
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func publicTag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.upsideGreen)
                .frame(width: 22, height: 22)
                .background(Color.upsideGreen.opacity(0.14))
                .clipShape(Circle())

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.62))

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.82))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct ProfileStatMetric: Identifiable {
    let title: String
    let value: String
    let subtitle: String
    let icon: String

    var id: String { title }
}

#Preview {
    HomeTabShellView(userRole: .creator)
}
