import SwiftUI

struct ChatStubView: View {
    @ObservedObject var viewModel: HomeFeedViewModel
    let initialConversationID: UUID?
    let onClose: () -> Void
    let showsCloseButton: Bool

    @State private var path: [UUID] = []
    @State private var lastRoutedConversationID: UUID?

    init(
        viewModel: HomeFeedViewModel,
        initialConversationID: UUID?,
        onClose: @escaping () -> Void,
        showsCloseButton: Bool = true
    ) {
        self.viewModel = viewModel
        self.initialConversationID = initialConversationID
        self.onClose = onClose
        self.showsCloseButton = showsCloseButton
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.black.ignoresSafeArea()

                if viewModel.conversations.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.conversations) { conversation in
                                ConversationRow(conversation: conversation) {
                                    viewModel.markConversationRead(conversation.id)
                                    path.append(conversation.id)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 18)
                    }
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close", action: onClose)
                            .foregroundColor(.white.opacity(0.82))
                    }
                }
            }
            .navigationDestination(for: UUID.self) { conversationID in
                if let conversation = conversationBinding(for: conversationID) {
                    ChatThreadView(
                        conversation: conversation,
                        currentUserInitials: viewModel.profile.initials,
                        onSaveDealDraft: { budget, deliverables, timeline, notes in
                            viewModel.saveDealDraft(
                                in: conversationID,
                                budget: budget,
                                deliverables: deliverables,
                                timeline: timeline,
                                notes: notes
                            )
                        },
                        onSend: { text in
                            viewModel.sendMessage(text, in: conversationID)
                        },
                        onSubmitDeal: { budget, deliverables, timeline, notes in
                            viewModel.submitDeal(
                                in: conversationID,
                                budget: budget,
                                deliverables: deliverables,
                                timeline: timeline,
                                notes: notes
                            )
                        },
                        onSendDraftDeal: {
                            viewModel.sendDraftDeal(in: conversationID)
                        },
                        onUpdateDealStatus: { status in
                            viewModel.updateDealStatus(status, in: conversationID)
                        },
                        onAppearThread: {
                            viewModel.markConversationRead(conversationID)
                        }
                    )
                } else {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        Text("Conversation unavailable")
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .onAppear {
            routeInitialConversationIfNeeded(targetID: initialConversationID)
        }
        .onChange(of: initialConversationID) { _, newValue in
            routeInitialConversationIfNeeded(targetID: newValue, force: true)
        }
        .onChange(of: viewModel.conversations.count) { _, _ in
            routeInitialConversationIfNeeded(targetID: initialConversationID)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No conversations yet")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            Text("Swipe right in Home to start a conversation.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.62))
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
    }

    private func routeInitialConversationIfNeeded(targetID: UUID?, force: Bool = false) {
        guard let targetID else { return }
        guard force || lastRoutedConversationID != targetID else { return }
        guard viewModel.conversations.contains(where: { $0.id == targetID }) else { return }
        lastRoutedConversationID = targetID

        DispatchQueue.main.async {
            path = [targetID]
        }
    }

    private func conversationBinding(for conversationID: UUID) -> Binding<Conversation>? {
        guard let index = viewModel.conversations.firstIndex(where: { $0.id == conversationID }) else {
            return nil
        }
        return $viewModel.conversations[index]
    }
}

private struct ConversationRow: View {
    let conversation: Conversation
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                avatar

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(conversation.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        Text(Self.timeFormatter.string(from: conversation.lastUpdatedAt))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.48))
                    }

                    Text(conversation.subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.58))
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(conversation.lastMessagePreview)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.74))
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        if let deal = conversation.deal {
                            Text(deal.status.label)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(deal.status == .accepted ? .black : .white.opacity(0.92))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(deal.status == .accepted ? Color.upsideGreen : Color.white.opacity(0.12))
                                .clipShape(Capsule())
                        }

                        if conversation.unreadCount > 0 {
                            Text("\(conversation.unreadCount)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.upsideGreen)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(conversation.needsLightAvatarBackground ? Color.white : Color.white.opacity(0.12))

            if conversation.isBrand {
                Image(conversation.avatarImageName)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            } else {
                Image(conversation.avatarImageName)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct ChatThreadView: View {
    @Binding var conversation: Conversation
    let currentUserInitials: String
    let onSaveDealDraft: (String, String, String, String) -> Void
    let onSend: (String) -> Void
    let onSubmitDeal: (String, String, String, String) -> Void
    let onSendDraftDeal: () -> Void
    let onUpdateDealStatus: (DealStatus) -> Void
    let onAppearThread: () -> Void

    @State private var draft = ""
    @State private var showPeerProfile = false
    @State private var showDealComposer = false
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            if let deal = conversation.deal {
                                dealCard(for: deal)
                            } else {
                                sendProposalPrompt
                            }

                            ForEach(conversation.messages) { message in
                                ChatBubbleRow(
                                    message: message,
                                    conversation: conversation,
                                    currentUserInitials: currentUserInitials
                                )
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isComposerFocused = false
                    }
                    .onAppear {
                        scrollToBottom(using: proxy)
                    }
                    .onChange(of: conversation.messages.count) { _, _ in
                        scrollToBottom(using: proxy)
                    }
                }

                composer
            }
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: { showPeerProfile = true }) {
                    Image(systemName: "person.text.rectangle")
                        .foregroundColor(.white.opacity(0.85))
                }
                Button(action: { showDealComposer = true }) {
                    Image(systemName: "doc.text")
                        .foregroundColor(.white.opacity(0.85))
                }
            }
        }
        .sheet(isPresented: $showPeerProfile) {
            UserProfileSheet(conversation: conversation)
                .presentationDetents([.medium])
                .presentationBackground(.black)
        }
        .sheet(isPresented: $showDealComposer) {
            DealComposerSheet(
                initialDeal: conversation.deal,
                onSaveDraft: { budget, deliverables, timeline, notes in
                    onSaveDealDraft(budget, deliverables, timeline, notes)
                },
                onSend: { budget, deliverables, timeline, notes in
                    onSubmitDeal(budget, deliverables, timeline, notes)
                }
            )
            .presentationDetents([.large])
            .presentationBackground(.black)
        }
        .onAppear(perform: onAppearThread)
    }

    private var sendProposalPrompt: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("No proposal yet")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text("Send a proposal to move this match into a deal.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.62))
            }

            Spacer()

            Button("Send") {
                showDealComposer = true
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.upsideGreen)
            .clipShape(Capsule())
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func dealCard(for deal: DealProposal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Text("Deal Proposal")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .leading) {
                dealStatusBadge(for: deal)
                    .hidden()
            }
            .overlay(alignment: .trailing) {
                dealStatusBadge(for: deal)
            }

            Text("\(deal.budget) • \(deal.deliverables)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))

            Text("Timeline: \(deal.timeline)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))

            if !deal.notes.isEmpty {
                Text(deal.notes)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.62))
                    .lineLimit(2)
            }

            if deal.status == .draft {
                HStack(spacing: 8) {
                    Button("Send") {
                        onSendDraftDeal()
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.upsideGreen)
                    .clipShape(Capsule())

                    Button("Edit") {
                        showDealComposer = true
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))

                    Spacer()
                }
            } else if deal.status == .sent {
                HStack(spacing: 8) {
                    Button("Accept") {
                        onUpdateDealStatus(.accepted)
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.upsideGreen)
                    .clipShape(Capsule())

                    Button("Decline") {
                        onUpdateDealStatus(.declined)
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())

                    Spacer()

                    Button("Edit") {
                        showDealComposer = true
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                }
            } else {
                Button("Edit Proposal") {
                    showDealComposer = true
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func dealStatusBadge(for deal: DealProposal) -> some View {
        Text(deal.status.label)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(deal.status == .accepted ? .black : .white.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(deal.status == .accepted ? Color.upsideGreen : Color.white.opacity(0.14))
            .clipShape(Capsule())
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Write a message", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .focused($isComposerFocused)
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            Button(action: send) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 42, height: 42)
                    .background(Color.upsideGreen)
                    .clipShape(Circle())
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1.0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 18)
        .background(
            Color.black.opacity(0.92)
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 0.5),
                    alignment: .top
                )
        )
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isComposerFocused = false
        draft = ""
        onSend(text)
    }

    private func scrollToBottom(using proxy: ScrollViewProxy) {
        guard let lastID = conversation.messages.last?.id else { return }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }
}

private struct ChatBubbleRow: View {
    let message: ChatMessage
    let conversation: Conversation
    let currentUserInitials: String

    var body: some View {
        switch message.sender {
        case .system:
            Text(message.text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
        case .me:
            HStack(alignment: .bottom, spacing: 8) {
                Spacer(minLength: 44)
                Text(message.text)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.upsideGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                currentUserAvatar
            }
        case .peer:
            HStack(alignment: .bottom, spacing: 8) {
                peerAvatar
                Text(message.text)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Spacer(minLength: 44)
            }
        }
    }

    private var peerAvatar: some View {
        ZStack {
            Circle()
                .fill(conversation.needsLightAvatarBackground ? Color.white : Color.white.opacity(0.12))

            if conversation.isBrand {
                Image(conversation.avatarImageName)
                    .resizable()
                    .scaledToFit()
                    .padding(4)
            } else {
                Image(conversation.avatarImageName)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }

    private var currentUserAvatar: some View {
        Circle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 28, height: 28)
            .overlay(
                Text(currentUserInitials)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
    }
}

private struct DealComposerSheet: View {
    let onSaveDraft: (String, String, String, String) -> Void
    let onSend: (String, String, String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var budget: String
    @State private var deliverables: String
    @State private var timeline: String
    @State private var notes: String

    init(
        initialDeal: DealProposal?,
        onSaveDraft: @escaping (String, String, String, String) -> Void,
        onSend: @escaping (String, String, String, String) -> Void
    ) {
        self.onSaveDraft = onSaveDraft
        self.onSend = onSend
        _budget = State(initialValue: initialDeal?.budget ?? "")
        _deliverables = State(initialValue: initialDeal?.deliverables ?? "")
        _timeline = State(initialValue: initialDeal?.timeline ?? "")
        _notes = State(initialValue: initialDeal?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        dealField(title: "Budget", text: $budget, placeholder: "AED 1,500")
                        dealField(title: "Deliverables", text: $deliverables, placeholder: "2 Reels, 1 Story")
                        dealField(title: "Timeline", text: $timeline, placeholder: "10 days")

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.82))

                            TextEditor(text: $notes)
                                .frame(minHeight: 120)
                                .padding(8)
                                .scrollContentBackground(.hidden)
                                .foregroundColor(.white)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                )
                        }
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Deal Proposal")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.82))
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Draft") {
                        onSaveDraft(
                            budget.trimmingCharacters(in: .whitespacesAndNewlines),
                            deliverables.trimmingCharacters(in: .whitespacesAndNewlines),
                            timeline.trimmingCharacters(in: .whitespacesAndNewlines),
                            notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .disabled(
                        budget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                        deliverables.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                        timeline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                        notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )

                    Button("Send") {
                        onSend(
                            budget.trimmingCharacters(in: .whitespacesAndNewlines),
                            deliverables.trimmingCharacters(in: .whitespacesAndNewlines),
                            timeline.trimmingCharacters(in: .whitespacesAndNewlines),
                            notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        dismiss()
                    }
                    .foregroundColor(.upsideGreen)
                    .disabled(
                        budget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        deliverables.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        timeline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
    }

    private func dealField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.82))
            TextField(placeholder, text: text)
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        }
    }
}

private struct UserProfileSheet: View {
    let conversation: Conversation

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        avatar

                        VStack(spacing: 6) {
                            Text(conversation.title)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            Text(conversation.peerProfile.headline)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.74))
                        }

                        profileCard(
                            title: "Snapshot",
                            content: conversation.peerProfile.metricLine
                        )

                        profileCard(
                            title: "About",
                            content: conversation.peerProfile.about
                        )

                        profileCard(
                            title: "Location",
                            content: conversation.peerProfile.location
                        )

                        if !conversation.peerProfile.tags.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Focus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.82))
                                HStack(spacing: 8) {
                                    ForEach(conversation.peerProfile.tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.88))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.white.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                    Spacer()
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(conversation.needsLightAvatarBackground ? Color.white : Color.white.opacity(0.14))

            if conversation.isBrand {
                Image(conversation.avatarImageName)
                    .resizable()
                    .scaledToFit()
                    .padding(16)
            } else {
                Image(conversation.avatarImageName)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: 98, height: 98)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }

    private func profileCard(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.82))
            Text(content)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.74))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    ChatStubView(
        viewModel: HomeFeedViewModel(userRole: .creator),
        initialConversationID: nil,
        onClose: {},
        showsCloseButton: true
    )
}
