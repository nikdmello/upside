import SwiftUI

struct HomeView: View {
    let userRole: UserRole
    @StateObject private var viewModel: HomeFeedViewModel
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    @State private var draggingCardID: UUID?
    @State private var showChat = false

    init(userRole: UserRole) {
        self.userRole = userRole
        _viewModel = StateObject(wrappedValue: HomeFeedViewModel(userRole: userRole))
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                Spacer(minLength: 12)

                if viewModel.cards.isEmpty {
                    emptyState
                        .padding(.horizontal, 24)
                } else {
                    cardDeck
                        .padding(.horizontal, 20)
                }

                Spacer(minLength: 18)

                actionBar
                    .padding(.bottom, 36)
            }

        }
        .sheet(isPresented: $viewModel.showMatch) {
            MatchModalView(onChat: {
                viewModel.showMatch = false
                showChat = true
            }, onClose: { viewModel.showMatch = false })
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .presentationBackground(.black)
        }
        .sheet(isPresented: $showChat) {
            ChatStubView(onClose: { showChat = false })
        }
        .coordinateSpace(name: "cardSpace")
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            UpsideLogo(height: 50)

            Spacer()

            Button(action: {}) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }

            Button(action: {}) {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "person.crop.circle")
                            .foregroundColor(.white.opacity(0.8))
                    )
            }
        }
    }

    private var cardDeck: some View {
        GeometryReader { geo in
            let cardWidth = geo.size.width
            let cardHeight: CGFloat = 520

            ZStack {
                let topCards = Array(viewModel.cards.prefix(3))
            ForEach(Array(topCards.enumerated()).reversed(), id: \.element.id) { index, card in
                let isTop = index == 0
                HomeCardView(
                    card: card,
                    userRole: userRole,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    showBadge: card.id == draggingCardID && isDragging,
                    dragAction: dragAction
                )
                    .scaleEffect(stackScale(for: index, isTop: isTop))
                    .offset(y: stackOffset(for: index, isTop: isTop))
                    .opacity(stackOpacity(for: index, isTop: isTop))
                    .shadow(color: .black.opacity(isTop ? 0.45 : 0.25), radius: isTop ? 18 : 10, x: 0, y: isTop ? 12 : 8)
                    .offset(card.id == draggingCardID ? dragOffset : .zero)
                    .rotationEffect(.degrees(card.id == draggingCardID && isDragging ? Double(dragOffset.width / 18) : 0))
                    .zIndex(card.id == draggingCardID ? 10 : Double(topCards.count - index))
                    .gesture(isTop ? dragGesture(for: card.id) : nil)
            }
        }
        .frame(height: cardHeight)
        .animation(.easeInOut(duration: 0.36), value: viewModel.currentCard?.id)
    }
        .frame(height: 520)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("You’re all caught up")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Fetching new matches in the background.")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.45))
                .multilineTextAlignment(.center)

            ProgressView()
                .tint(.upsideGreen)
                .scaleEffect(0.9)
                .opacity(0.5)
        }
        .frame(maxWidth: .infinity, maxHeight: 520)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var actionBar: some View {
        HStack(spacing: 24) {
            ActionButton(icon: "xmark", color: .white.opacity(0.9)) {
                performAction(.skip)
            }
            ActionButton(icon: "star.fill", color: .white.opacity(0.9)) {
                performAction(.save)
            }
            ActionButton(icon: "heart.fill", color: .black, fill: .upsideGreen) {
                performAction(.match)
            }
        }
        .padding(.horizontal, 32)
    }

    private var dragAction: SwipeAction? {
        if dragOffset.width > 120 { return .match }
        if dragOffset.width < -120 { return .skip }
        if dragOffset.height < -120 { return .save }
        return nil
    }

    private func dragGesture(for cardID: UUID) -> some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                if draggingCardID == nil {
                    draggingCardID = cardID
                }
                dragOffset = value.translation
            }
            .onEnded { _ in
                isDragging = false
                guard draggingCardID == cardID else { return }
                guard let action = dragAction else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        dragOffset = .zero
                    }
                    draggingCardID = nil
                    return
                }

                withAnimation(.easeInOut(duration: 0.25)) {
                    dragOffset = swipeTargetOffset(for: action)
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                    withAnimation(.easeInOut(duration: 0.32)) {
                        viewModel.swipe(action)
                    }
                    dragOffset = .zero
                    draggingCardID = nil
                }
            }
    }

    private func performAction(_ action: SwipeAction) {
        if draggingCardID == nil {
            draggingCardID = viewModel.currentCard?.id
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            dragOffset = swipeTargetOffset(for: action, initial: defaultDirection(for: action))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
            withAnimation(.easeInOut(duration: 0.32)) {
                viewModel.swipe(action)
            }
            dragOffset = .zero
            draggingCardID = nil
        }
    }

    private func swipeTargetOffset(for action: SwipeAction, initial: CGSize? = nil) -> CGSize {
        var direction = initial ?? dragOffset
        let magnitude = max(1, sqrt(direction.width * direction.width + direction.height * direction.height))
        let offscreenDistance = max(800, magnitude * 2.2)

        switch action {
        case .match:
            if direction.width < 120 { direction.width = 120 }
        case .skip:
            if direction.width > -120 { direction.width = -120 }
        case .save:
            if direction.height > -120 { direction.height = -120 }
        }

        let scale = offscreenDistance / magnitude
        return CGSize(width: direction.width * scale, height: direction.height * scale)
    }

    private func defaultDirection(for action: SwipeAction) -> CGSize {
        switch action {
        case .match:
            return CGSize(width: 180, height: -20)
        case .skip:
            return CGSize(width: -180, height: -10)
        case .save:
            return CGSize(width: 0, height: -220)
        }
    }

    private func stackScale(for index: Int, isTop: Bool) -> CGFloat {
        if isTop { return 1.0 }
        return index == 1 ? 0.98 : 0.96
    }

    private func stackOffset(for index: Int, isTop: Bool) -> CGFloat {
        if isTop { return 0 }
        return index == 1 ? 10 : 20
    }

    private func stackOpacity(for index: Int, isTop: Bool) -> Double {
        if isTop { return 1.0 }
        return index == 1 ? 0.94 : 0.88
    }
}

struct HomeCardView: View {
    let card: HomeCard
    let userRole: UserRole
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let showBadge: Bool
    let dragAction: SwipeAction?

    var body: some View {
        GeometryReader { proxy in
            let heroHeight = proxy.size.height * 0.75

            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    cardHero
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    LinearGradient(
                        colors: [Color.black.opacity(0.0), Color.black.opacity(0.35)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                }
                .frame(height: heroHeight)

                detailsSection
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
                    .background(Color.black)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if showBadge, let action = dragAction {
                    SwipeBadge(action: action)
                        .padding(20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: badgeAlignment(for: action))
                }
            }
        }
        .frame(height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.black)
        )
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.6), radius: 28, x: 0, y: 18)
        .frame(maxWidth: cardWidth)
    }

    private var cardTitle: String {
        switch card {
        case .brand(let brand): return brand.name
        case .creator(let creator): return creator.handle
        }
    }

    private var cardSubtitle: String {
        switch card {
        case .brand(let brand): return brand.campaign
        case .creator(let creator): return creator.niche
        }
    }

    private var cardImageName: String {
        switch card {
        case .brand(let brand): return brand.imageName
        case .creator(let creator): return creator.imageName
        }
    }

    private var isBrandCard: Bool {
        if case .brand = card { return true }
        return false
    }

    private var brandNeedsWhiteBG: Bool {
        guard case .brand(let brand) = card else { return false }
        return ["Sephora", "Allbirds", "Apple", "Nike"].contains(brand.name)
    }

    private var cardChips: [String] {
        switch card {
        case .brand(let brand):
            return [brand.budget, brand.deliverables]
        case .creator(let creator):
            return [creator.followers, creator.engagementRate]
        }
    }

    private var cardHeadline: String {
        switch card {
        case .brand: return "Campaign Details"
        case .creator: return "Creator Snapshot"
        }
    }

    private var cardMeta: String {
        switch card {
        case .brand(let brand):
            return "Budget: \(brand.budget) • \(brand.deliverables)"
        case .creator(let creator):
            return "\(creator.followers) followers • \(creator.engagementRate)"
        }
    }

    private var cardPitch: String {
        switch card {
        case .brand(let brand): return brand.pitch
        case .creator(let creator): return creator.pitch
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(cardTitle)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            Text(cardSubtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.75))
                .lineLimit(1)

            HStack(spacing: 8) {
                ForEach(cardChips, id: \.self) { chip in
                    Text(chip)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cardHero: some View {
        Group {
            if isBrandCard {
                ZStack {
                    if brandNeedsWhiteBG {
                        Color.white
                    } else {
                        Color.black
                    }
                    Image(cardImageName)
                        .resizable()
                        .scaledToFit()
                        .padding(44)
                }
            } else {
                Image(cardImageName)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private func badgeAlignment(for action: SwipeAction) -> Alignment {
        switch action {
        case .match:
            return .topLeading
        case .skip:
            return .topTrailing
        case .save:
            return .top
        }
    }
}

struct ActionButton: View {
    let icon: String
    let color: Color
    var fill: Color = Color.white.opacity(0.08)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
                .frame(width: 56, height: 56)
                .background(fill)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
    }
}

struct SwipeBadge: View {
    let action: SwipeAction?

    var body: some View {
        Group {
            switch action {
            case .match:
                badge(text: "MATCH", color: .upsideGreen)
            case .skip:
                badge(text: "SKIP", color: .red)
            case .save:
                badge(text: "SAVE", color: .white.opacity(0.8))
            case .none:
                EmptyView()
            }
        }
    }

    private func badge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.6))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
    }
}

struct MatchModalView: View {
    let onChat: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.upsideGreen.opacity(0.15))
                    .frame(width: 84, height: 84)
                    .overlay(
                        Circle()
                            .stroke(Color.upsideGreen.opacity(0.35), lineWidth: 1)
                    )

                Image(systemName: "sparkles")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.upsideGreen)
            }

            VStack(spacing: 8) {
                Text("It’s a match")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text("Start the conversation and lock the deal.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }

            Button(action: onChat) {
                Text("Start Chat")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.upsideGreen)
                    .cornerRadius(28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: Color.upsideGreen.opacity(0.4), radius: 16, x: 0, y: 10)
            }

            Button(action: onClose) {
                Text("Maybe later")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(26)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }
}

#Preview {
    HomeView(userRole: .creator)
}
