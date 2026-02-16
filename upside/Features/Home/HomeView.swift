import SwiftUI

struct HomeView: View {
    let userRole: UserRole
    @StateObject private var viewModel: HomeFeedViewModel
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    @State private var draggingCardID: UUID?
    @State private var showChat = false
    private let tossAnimation = Animation.interactiveSpring(response: 0.24, dampingFraction: 0.86, blendDuration: 0.12)
    private let stackAnimation = Animation.interactiveSpring(response: 0.28, dampingFraction: 0.88, blendDuration: 0.1)

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
                    cardHeight: cardHeight
                )
                    .scaleEffect(stackScale(for: index, isTop: isTop))
                    .offset(y: stackOffset(for: index, isTop: isTop))
                    .opacity(stackOpacity(for: index, isTop: isTop))
                    .shadow(
                        color: .black.opacity(isTop ? (isDragging ? 0.28 : 0.42) : 0.18),
                        radius: isTop ? (isDragging ? 11 : 16) : 8,
                        x: 0,
                        y: isTop ? (isDragging ? 7 : 10) : 6
                    )
                    .offset(card.id == draggingCardID ? dragOffset : .zero)
                    .rotationEffect(.degrees(card.id == draggingCardID ? Double(dragOffset.width / 18) : 0))
                    .zIndex(card.id == draggingCardID ? 100 : Double(topCards.count - index))
                    .gesture(isTop ? dragGesture(for: card.id) : nil)
            }

            if let topCardID = topCards.first?.id,
               topCardID == draggingCardID,
               isDragging,
               let action = dragCueAction {
                SwipeBadge(action: action)
                    .padding(dragBadgePadding)
                    .frame(width: cardWidth, height: cardHeight, alignment: dragBadgeAlignment)
                    .offset(x: dragOffset.width, y: dragOffset.height)
                    .rotationEffect(.degrees(Double(dragOffset.width / 18)))
                    .zIndex(300)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: cardHeight)
        .animation(stackAnimation, value: viewModel.currentCard?.id)
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

    private var dragCueAction: SwipeAction? {
        let x = dragOffset.width
        let y = dragOffset.height
        let threshold: CGFloat = 8

        guard abs(x) > threshold || abs(y) > threshold else {
            return nil
        }

        if abs(x) >= abs(y) {
            return x > 0 ? .match : .skip
        }
        if y < 0 {
            return .save
        }
        return nil
    }

    private var dragBadgeAlignment: Alignment {
        switch dragCueAction {
        case .match:
            return .topLeading
        case .skip:
            return .topTrailing
        case .save:
            return .top
        case .none:
            return .top
        }
    }

    private var dragBadgePadding: EdgeInsets {
        switch dragCueAction {
        case .match:
            return EdgeInsets(top: 10, leading: 10, bottom: 0, trailing: 0)
        case .skip:
            return EdgeInsets(top: 10, leading: 0, bottom: 0, trailing: 10)
        case .save:
            return EdgeInsets(top: 10, leading: 0, bottom: 0, trailing: 0)
        case .none:
            return EdgeInsets()
        }
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
            .onEnded { value in
                isDragging = false
                guard draggingCardID == cardID else { return }
                let translation = value.translation
                let predicted = value.predictedEndTranslation

                guard let action = releaseAction(translation: translation, predicted: predicted) else {
                    withAnimation(tossAnimation) {
                        dragOffset = .zero
                    }
                    draggingCardID = nil
                    return
                }

                withAnimation(tossAnimation) {
                    dragOffset = swipeTargetOffset(
                        for: action,
                        initial: releaseDirection(for: action, translation: translation, predicted: predicted)
                    )
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(stackAnimation) {
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
        withAnimation(tossAnimation) {
            dragOffset = swipeTargetOffset(for: action, initial: defaultDirection(for: action))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(stackAnimation) {
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

        // Only clamp fallback drag vectors. Explicit release vectors should preserve trajectory.
        if initial == nil {
            switch action {
            case .match:
                if direction.width < 120 { direction.width = 120 }
            case .skip:
                if direction.width > -120 { direction.width = -120 }
            case .save:
                if direction.height > -120 { direction.height = -120 }
            }
        }

        let scale = offscreenDistance / magnitude
        return CGSize(width: direction.width * scale, height: direction.height * scale)
    }

    private func releaseAction(translation: CGSize, predicted: CGSize) -> SwipeAction? {
        if translation.width > 120 || predicted.width > 180 { return .match }
        if translation.width < -120 || predicted.width < -180 { return .skip }
        if translation.height < -120 || predicted.height < -220 { return .save }
        return nil
    }

    private func releaseDirection(for action: SwipeAction, translation: CGSize, predicted: CGSize) -> CGSize {
        let momentum = CGSize(
            width: predicted.width - translation.width,
            height: predicted.height - translation.height
        )

        var direction = CGSize(
            width: translation.width + (momentum.width * 1.1),
            height: translation.height + (momentum.height * 0.9)
        )

        switch action {
        case .match:
            // Add slight upward lift so horizontal swipes feel like a toss, not a flat slide.
            direction.height -= min(120, abs(momentum.width) * 0.18)
            if direction.height > -28 { direction.height = -28 }
            if direction.width < 160 { direction.width = 160 }
        case .skip:
            direction.height -= min(120, abs(momentum.width) * 0.18)
            if direction.height > -28 { direction.height = -28 }
            if direction.width > -160 { direction.width = -160 }
        case .save:
            if direction.height > -220 { direction.height = -220 }
            if abs(direction.width) > 90 { direction.width = direction.width.sign == .minus ? -90 : 90 }
        }

        if abs(direction.width) < 10 && abs(direction.height) < 10 {
            return defaultDirection(for: action)
        }
        return direction
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
        return index == 1 ? 0.965 : 0.93
    }

    private func stackOffset(for index: Int, isTop: Bool) -> CGFloat {
        if isTop { return 0 }
        return index == 1 ? 18 : 36
    }

    private func stackOpacity(for index: Int, isTop: Bool) -> Double {
        _ = index
        _ = isTop
        return 1.0
    }

}

struct HomeCardView: View {
    let card: HomeCard
    let userRole: UserRole
    let cardWidth: CGFloat
    let cardHeight: CGFloat

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
        .compositingGroup()
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
