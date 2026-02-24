import SwiftUI

struct HomeView: View {
    let userRole: UserRole
    @ObservedObject var viewModel: HomeFeedViewModel
    var onOpenInbox: ((UUID?) -> Void)? = nil
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    @State private var draggingCardID: UUID?
    @State private var showChat = false
    @State private var showFilters = false
    @State private var showShortlist = false
    @State private var initialChatConversationID: UUID?
    @State private var selectedDetailCard: HomeCard?
    @State private var detailExpandProgress: CGFloat = 0
    @State private var topCardFrame: CGRect = .zero
    @State private var topBarFrame: CGRect = .zero
    @State private var detailSourceCardFrame: CGRect = .zero
    @State private var detailSourceTopBarFrame: CGRect = .zero
    private let tossAnimation = Animation.interactiveSpring(response: 0.24, dampingFraction: 0.86, blendDuration: 0.12)
    private let stackAnimation = Animation.interactiveSpring(response: 0.28, dampingFraction: 0.88, blendDuration: 0.1)
    private let detailExpandAnimation = Animation.interactiveSpring(response: 0.34, dampingFraction: 0.92, blendDuration: 0.12)

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, -4)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: TopBarFramePreferenceKey.self,
                                value: proxy.frame(in: .named("homeRoot"))
                            )
                        }
                    )

                Spacer(minLength: 2)

                if viewModel.cards.isEmpty {
                    emptyState
                        .padding(.horizontal, 24)
                } else {
                    cardDeck
                        .padding(.horizontal, 20)
                }

                Spacer(minLength: 10)

                actionBar
                    .padding(.bottom, 30)
            }
            .allowsHitTesting(selectedDetailCard == nil)

            if let card = selectedDetailCard {
                HomeCardDetailOverlay(
                    card: card,
                    topCardFrame: detailSourceCardFrame == .zero ? topCardFrame : detailSourceCardFrame,
                    topBarFrame: detailSourceTopBarFrame == .zero ? topBarFrame : detailSourceTopBarFrame,
                    expandProgress: detailExpandProgress,
                    onClose: closeCardDetail
                )
                .zIndex(500)
            }

        }
        .onPreferenceChange(TopCardFramePreferenceKey.self) { frame in
            guard frame != .zero else { return }
            guard selectedDetailCard == nil else { return }
            topCardFrame = frame
        }
        .onPreferenceChange(TopBarFramePreferenceKey.self) { frame in
            guard frame != .zero else { return }
            guard selectedDetailCard == nil else { return }
            topBarFrame = frame
        }
        .sheet(isPresented: $viewModel.showMatch) {
            MatchModalView(onChat: {
                viewModel.showMatch = false
                openInbox(viewModel.latestMatchConversationID)
            }, onClose: { viewModel.showMatch = false })
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .presentationBackground(.black)
        }
        .sheet(isPresented: $showChat, onDismiss: {
            initialChatConversationID = nil
        }) {
            ChatStubView(
                viewModel: viewModel,
                initialConversationID: initialChatConversationID,
                onClose: { showChat = false }
            )
        }
        .sheet(isPresented: $showFilters) {
            HomeFilterSheet(
                role: userRole,
                initialFilters: viewModel.filters,
                onApply: { updated in
                    viewModel.applyFilters(updated)
                    showFilters = false
                },
                onReset: {
                    viewModel.resetFilters()
                    showFilters = false
                },
                onClose: { showFilters = false }
            )
                .presentationDetents([.large])
                .presentationBackground(.black)
        }
        .sheet(isPresented: $showShortlist) {
            SavedShortlistSheet(
                cards: viewModel.savedCards,
                onMatch: { card in
                    showShortlist = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        viewModel.matchSavedCard(card)
                    }
                },
                onUnsave: { card in
                    viewModel.unsaveCard(card)
                },
                onSkip: { card in
                    viewModel.skipSavedCard(card)
                },
                onClose: {
                    showShortlist = false
                }
            )
            .presentationDetents([.large])
            .presentationBackground(.black)
        }
        .coordinateSpace(name: "homeRoot")
        .coordinateSpace(name: "cardSpace")
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            UpsideLogo(height: 50)

            Spacer()

            Button(action: { showFilters = true }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())

                    if viewModel.filters.activeCount(for: userRole) > 0 {
                        Text("\(viewModel.filters.activeCount(for: userRole))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.upsideGreen)
                            .clipShape(Capsule())
                            .offset(x: 8, y: -6)
                    }
                }
            }

            Button(action: { showShortlist = true }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())

                    if !viewModel.savedCards.isEmpty {
                        Text("\(viewModel.savedCards.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.upsideGreen)
                            .clipShape(Capsule())
                            .offset(x: 8, y: -6)
                    }
                }
            }
        }
    }

    private var cardDeck: some View {
        GeometryReader { geo in
            let cardWidth = geo.size.width
            let cardHeight: CGFloat = 540

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
                    .opacity(cardOpacity(for: card, index: index, isTop: isTop))
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
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: TopCardFramePreferenceKey.self,
                                value: isTop ? proxy.frame(in: .named("homeRoot")) : .zero
                            )
                        }
                    )
                    .onTapGesture {
                        guard isTop, !isDragging else { return }
                        let feedback = UIImpactFeedbackGenerator(style: .light)
                        feedback.impactOccurred()
                        openCardDetail(card)
                    }
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
        .frame(height: 540)
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
        .frame(maxWidth: .infinity, maxHeight: 540)
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
        HStack(spacing: 18) {
            if viewModel.canUndoSkip {
                ActionButton(icon: "arrow.uturn.backward", color: .white.opacity(0.92), fill: Color.white.opacity(0.1)) {
                    _ = viewModel.undoLastSkip()
                }
            }

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
        .padding(.horizontal, viewModel.canUndoSkip ? 20 : 32)
    }

    private func openInbox(_ conversationID: UUID?) {
        if let onOpenInbox {
            onOpenInbox(conversationID)
            return
        }
        initialChatConversationID = conversationID
        showChat = true
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

    private func cardOpacity(for card: HomeCard, index: Int, isTop: Bool) -> Double {
        _ = card
        if selectedDetailCard != nil {
            return 0
        }
        return stackOpacity(for: index, isTop: isTop)
    }

    private func openCardDetail(_ card: HomeCard) {
        guard selectedDetailCard == nil else { return }
        detailExpandProgress = 0
        detailSourceCardFrame = topCardFrame
        detailSourceTopBarFrame = topBarFrame
        selectedDetailCard = card
        DispatchQueue.main.async {
            withAnimation(detailExpandAnimation) {
                detailExpandProgress = 1
            }
        }
    }

    private func closeCardDetail() {
        guard selectedDetailCard != nil else { return }
        withAnimation(detailExpandAnimation) {
            detailExpandProgress = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            if detailExpandProgress == 0 {
                selectedDetailCard = nil
                detailSourceCardFrame = .zero
                detailSourceTopBarFrame = .zero
            }
        }
    }
}

private struct HomeCardDetailOverlay: View {
    let card: HomeCard
    let topCardFrame: CGRect
    let topBarFrame: CGRect
    let expandProgress: CGFloat
    let onClose: () -> Void
    @State private var closeDragOffsetY: CGFloat = 0
    @State private var didTriggerCloseDuringDrag = false
    @State private var isClosing = false
    @State private var isDetailScrollAtTop = false
    @State private var closeGestureBeganAtTop: Bool?
    @State private var didScrollAwayFromTop = false
    @State private var didTriggerCloseFromScroll = false

    var body: some View {
        GeometryReader { proxy in
            let collapsedFrame = topCardFrame == .zero
                ? CGRect(x: 20, y: proxy.safeAreaInsets.top + 94, width: proxy.size.width - 40, height: 520)
                : topCardFrame
            let headerSpace = proxy.safeAreaInsets.top + 60
            let candidateExpandedTopY = max(headerSpace, collapsedFrame.minY - 170)
            let expandedTopY = min(candidateExpandedTopY, collapsedFrame.minY - 24)
            // Keep the expanded card clear of the tab bar/home indicator area so detail rows stay visible.
            let expandedBottomInset = max(proxy.safeAreaInsets.bottom + 52, 56)
            let expandedHeight = max(500, proxy.size.height - expandedTopY - expandedBottomInset)
            let expandedFrame = CGRect(
                x: 10,
                y: expandedTopY,
                width: proxy.size.width - 20,
                height: expandedHeight
            )
            let progress = min(max(expandProgress, 0), 1)
            let currentFrame = lerpRect(from: collapsedFrame, to: expandedFrame, progress: progress)
            let canInteractAsExpanded = progress > 0.88
            let closeGestureMask: GestureMask = (isDetailScrollAtTop && !isClosing) ? .all : .subviews

            ZStack(alignment: .top) {
                Color.black.opacity(backgroundOpacity)
                    .padding(.top, headerSpace)
                    .ignoresSafeArea(edges: [.horizontal, .bottom])
                    .onTapGesture {
                        triggerClose()
                    }

                HomeCardDetailSheet(
                    card: card,
                    onDone: onClose,
                    useNavigationChrome: false,
                    expandProgress: progress,
                    isDismissingDragActive: canInteractAsExpanded && (closeDragOffsetY > 0 || isClosing),
                    onScrollTopStateChange: { isAtTop in
                        let wasAtTop = isDetailScrollAtTop
                        isDetailScrollAtTop = isAtTop

                        guard canInteractAsExpanded else { return }
                        guard !didTriggerCloseDuringDrag, !didTriggerCloseFromScroll else { return }

                        if !isAtTop {
                            didScrollAwayFromTop = true
                            return
                        }

                        let reachedTopFromScroll = !wasAtTop && isAtTop
                        guard reachedTopFromScroll, didScrollAwayFromTop else { return }

                        didTriggerCloseFromScroll = true
                        closeDragOffsetY = 0
                        triggerClose()
                    }
                )
                .frame(
                    width: currentFrame.width,
                    height: currentFrame.height
                )
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 26 + ((1 - progress) * 6), style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 26 + ((1 - progress) * 6), style: .continuous)
                        .stroke(Color.white.opacity(0.08 + ((1 - progress) * 0.04)), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.36 + (progress * 0.12)), radius: 16 + (progress * 10), x: 0, y: 8 + (progress * 4))
                .scaleEffect(canInteractAsExpanded ? dragScale : 1)
                .position(
                    x: currentFrame.midX,
                    y: currentFrame.midY + (canInteractAsExpanded ? closeDragOffsetY : 0)
                )
                .simultaneousGesture(closeDragGesture, including: closeGestureMask)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(edges: [.horizontal, .bottom])
    }

    private var dragProgress: CGFloat {
        guard expandProgress > 0.88 else { return 0 }
        return min(max(closeDragOffsetY / 260, 0), 1)
    }

    private var dragScale: CGFloat {
        1 - (dragProgress * 0.035)
    }

    private var backgroundOpacity: Double {
        let base = 0.72 * Double(expandProgress)
        return base * Double(1 - (dragProgress * 0.85))
    }

    private var closeDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard expandProgress > 0.88 else { return }
                if closeGestureBeganAtTop == nil {
                    closeGestureBeganAtTop = isDetailScrollAtTop
                }
                guard closeGestureBeganAtTop == true else {
                    closeDragOffsetY = 0
                    return
                }
                guard isDetailScrollAtTop else {
                    closeDragOffsetY = 0
                    return
                }
                guard !didTriggerCloseDuringDrag else { return }
                let dragY = max(0, value.translation.height)
                closeDragOffsetY = dragY

                // Allow a short downward pull to dismiss immediately, without waiting for finger lift.
                if dragY > 16 {
                    didTriggerCloseDuringDrag = true
                    closeDragOffsetY = 0
                    triggerClose()
                }
            }
            .onEnded { value in
                defer {
                    didTriggerCloseDuringDrag = false
                    closeGestureBeganAtTop = nil
                }
                guard expandProgress > 0.88 else {
                    closeDragOffsetY = 0
                    return
                }
                guard closeGestureBeganAtTop == true else {
                    closeDragOffsetY = 0
                    return
                }
                guard isDetailScrollAtTop else {
                    closeDragOffsetY = 0
                    return
                }
                if didTriggerCloseDuringDrag {
                    closeDragOffsetY = 0
                    return
                }
                let shouldClose = value.translation.height > 26 || value.predictedEndTranslation.height > 56
                if shouldClose {
                    closeDragOffsetY = 0
                    triggerClose()
                    return
                }
                withAnimation(.spring(response: 0.33, dampingFraction: 0.85)) {
                    closeDragOffsetY = 0
                }
            }
    }

    private func lerpRect(from: CGRect, to: CGRect, progress: CGFloat) -> CGRect {
        CGRect(
            x: from.minX + ((to.minX - from.minX) * progress),
            y: from.minY + ((to.minY - from.minY) * progress),
            width: from.width + ((to.width - from.width) * progress),
            height: from.height + ((to.height - from.height) * progress)
        )
    }

    private func triggerClose() {
        guard !isClosing else { return }
        isClosing = true
        onClose()
    }
}

private struct TopCardFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

private struct TopBarFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

struct HomeCardView: View {
    let card: HomeCard
    let userRole: UserRole
    let cardWidth: CGFloat
    let cardHeight: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let metricsBarHeight: CGFloat = 74
            let heroHeight = max(0, proxy.size.height - metricsBarHeight)

            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    cardHero
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: Color.black.opacity(0.14), location: 0.42),
                            .init(color: Color.black.opacity(0.5), location: 0.78),
                            .init(color: Color.black.opacity(0.78), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 170)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(cardTitle)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(cardSubtitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.82))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
                }
                .frame(height: heroHeight)
                .clipped()

                detailsSection
                    .frame(maxWidth: .infinity)
                    .frame(height: metricsBarHeight, alignment: .topLeading)
                    .background(Color.black)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)
                    }
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

    private var creatorImageYOffset: CGFloat {
        guard case .creator(let creator) = card else { return 0 }
        switch creator.imageName {
        case "Creator_jxshdxniells", "Creator_srav.ya":
            return -18
        default:
            return -4
        }
    }

    private var creatorImageScale: CGFloat {
        guard case .creator(let creator) = card else { return 1 }
        switch creator.imageName {
        case "Creator_jxshdxniells", "Creator_srav.ya":
            return 1.12
        default:
            return 1.04
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
        HStack(spacing: 8) {
            ForEach(cardChips, id: \.self) { chip in
                Text(chip)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
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
                ZStack {
                    // Backfill transparent edges so creator assets never reveal a black strip.
                    Image(cardImageName)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(max(creatorImageScale, 1.12))
                        .blur(radius: 14)
                        .opacity(0.42)

                    Image(cardImageName)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(creatorImageScale, anchor: .top)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .offset(y: creatorImageYOffset)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

}

struct HomeCardDetailSheet: View {
    let card: HomeCard
    var onDone: (() -> Void)? = nil
    var useNavigationChrome: Bool = true
    var expandProgress: CGFloat = 1
    var isDismissingDragActive: Bool = false
    var onScrollTopStateChange: ((Bool) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if useNavigationChrome {
                NavigationStack {
                    detailContent
                        .navigationTitle("Profile")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    handleDone()
                                }
                                .foregroundColor(.upsideGreen)
                            }
                        }
                }
            } else {
                detailContent
            }
        }
    }

    private var detailContent: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        heroSection(height: heroHeight(for: proxy.size.height))

                        VStack(spacing: 14) {
                            summaryCard
                            detailsCard
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .opacity(expandedDetailsOpacity)
                        .offset(y: expandedDetailsOffsetY)
                        .overlay(alignment: .topLeading) {
                            collapsedDetailsPreview
                                .padding(.horizontal, 20)
                                .padding(.top, 14)
                                .opacity(collapsedDetailsOpacity)
                                .offset(y: collapsedDetailsOffsetY)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.bottom, 96)
                }
                .background(VerticalScrollBounceDisabler())
                .scrollDisabled(isDismissingDragActive)
                .scrollIndicators(.hidden)
                .onAppear {
                    onScrollTopStateChange?(true)
                }
                .onScrollGeometryChange(
                    for: Bool.self,
                    of: { geometry in
                        geometry.contentOffset.y <= geometry.contentInsets.top + 0.5
                    },
                    action: { _, isAtTop in
                        onScrollTopStateChange?(isAtTop)
                    }
                )
                .overlay(alignment: .top) {
                    if !useNavigationChrome {
                        Capsule()
                            .fill(Color.white.opacity(0.78))
                            .frame(width: 44, height: 5)
                            .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
                            .padding(.top, 11)
                            .opacity(Double(max(0, min(1, (expandProgress - 0.55) / 0.45))))
                            .allowsHitTesting(false)
                    }
                }
            }
        }
    }

    private func handleDone() {
        if let onDone {
            onDone()
        } else {
            dismiss()
        }
    }

    private func heroSection(height: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
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
                    ZStack {
                        // Backfill transparent edges so creator assets never reveal a black strip.
                        Image(cardImageName)
                            .resizable()
                            .scaledToFill()
                            .scaleEffect(max(creatorImageScale, 1.12))
                            .blur(radius: 14)
                            .opacity(0.42)

                        Image(cardImageName)
                            .resizable()
                            .scaledToFill()
                            .scaleEffect(creatorImageScale, anchor: .top)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .offset(y: creatorImageYOffset)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: Color.black.opacity(0.12), location: 0.36),
                    .init(color: Color.black.opacity(0.58), location: 0.78),
                    .init(color: Color.black, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 180)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

            VStack(alignment: .leading, spacing: 4) {
                Text(cardTitle)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)

                Text(cardSubtitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.84))
            }
            .padding(16)
            .opacity(heroTitleOpacity)
            .offset(y: heroTitleOffsetY)
        }
        .frame(height: height)
    }

    private func heroHeight(for containerHeight: CGFloat) -> CGFloat {
        let clampedProgress = max(0, min(1, expandProgress))
        // Match the collapsed card hero at progress 0 so images do not jump during open/close.
        let collapsedHeroHeight = max(0, containerHeight - 74)
        let expandedHeroHeight = min(560, max(480, containerHeight * 0.68))
        return collapsedHeroHeight + ((expandedHeroHeight - collapsedHeroHeight) * clampedProgress)
    }

    private var clampedExpandProgress: CGFloat {
        max(0, min(1, expandProgress))
    }

    private var heroTextProgress: CGFloat {
        smoothStep(normalize(clampedExpandProgress, start: 0.12, end: 0.55))
    }

    private var heroTitleOpacity: Double {
        1
    }

    private var heroTitleOffsetY: CGFloat {
        0
    }

    private var expandedDetailsProgress: CGFloat {
        smoothStep(normalize(clampedExpandProgress, start: 0.2, end: 0.96))
    }

    private var expandedDetailsOpacity: Double {
        Double(expandedDetailsProgress)
    }

    private var expandedDetailsOffsetY: CGFloat {
        (1 - expandedDetailsProgress) * 20
    }

    private var collapsedDetailsOpacity: Double {
        Double(1 - smoothStep(normalize(clampedExpandProgress, start: 0.06, end: 0.4)))
    }

    private var collapsedDetailsOffsetY: CGFloat {
        smoothStep(normalize(clampedExpandProgress, start: 0.0, end: 0.4)) * 10
    }

    private var collapsedDetailsPreview: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            HStack(spacing: 8) {
                ForEach(summaryChips, id: \.self) { chip in
                    Text(chip)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black)
    }

    private func normalize(_ value: CGFloat, start: CGFloat, end: CGFloat) -> CGFloat {
        guard end > start else { return value >= end ? 1 : 0 }
        return min(max((value - start) / (end - start), 0), 1)
    }

    private func smoothStep(_ t: CGFloat) -> CGFloat {
        t * t * (3 - (2 * t))
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(summaryChips, id: \.self) { chip in
                    Text(chip)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.88))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(cardPitch)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.82))
                .lineSpacing(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isBrandCard ? "Campaign Details" : "Creator Details")
                .font(.system(size: 13, weight: .bold))
                .kerning(0.5)
                .foregroundColor(.white.opacity(0.62))
                .textCase(.uppercase)

            ForEach(detailRows, id: \.title) { row in
                detailRow(icon: row.icon, title: row.title, value: row.value)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.upsideGreen)
                .frame(width: 22, height: 22)
                .background(Color.upsideGreen.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.62))
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.88))
            }

            Spacer(minLength: 0)
        }
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

    private var creatorImageYOffset: CGFloat {
        guard case .creator(let creator) = card else { return 0 }
        switch creator.imageName {
        case "Creator_jxshdxniells", "Creator_srav.ya":
            return -18
        default:
            return -4
        }
    }

    private var creatorImageScale: CGFloat {
        guard case .creator(let creator) = card else { return 1 }
        switch creator.imageName {
        case "Creator_jxshdxniells", "Creator_srav.ya":
            return 1.12
        default:
            return 1.04
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

    private var cardPitch: String {
        switch card {
        case .brand(let brand): return brand.pitch
        case .creator(let creator): return creator.pitch
        }
    }

    private var summaryChips: [String] {
        switch card {
        case .brand(let brand):
            return [brand.budget, brand.deliverables]
        case .creator(let creator):
            return [creator.followers, creator.engagementRate]
        }
    }

    private var detailRows: [(icon: String, title: String, value: String)] {
        switch card {
        case .brand(let brand):
            return [
                ("megaphone.fill", "Campaign", brand.campaign),
                ("banknote.fill", "Budget", brand.budget),
                ("checklist", "Deliverables", brand.deliverables),
                ("sparkles", "Fit", brand.pitch)
            ]
        case .creator(let creator):
            return [
                ("person.2.fill", "Niche", creator.niche),
                ("chart.bar.fill", "Followers", creator.followers),
                ("waveform.path.ecg", "Engagement", creator.engagementRate)
            ]
        }
    }
}

private struct VerticalScrollBounceDisabler: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        UIView(frame: .zero)
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            guard let scrollView = uiView.enclosingScrollView() else { return }
            scrollView.bounces = false
            scrollView.alwaysBounceVertical = false
            scrollView.alwaysBounceHorizontal = false
        }
    }
}

private extension UIView {
    func enclosingScrollView() -> UIScrollView? {
        var view: UIView? = self
        while let current = view {
            if let scrollView = current as? UIScrollView {
                return scrollView
            }
            view = current.superview
        }
        return nil
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

struct HomeFilterSheet: View {
    let role: UserRole
    let onApply: (HomeFilters) -> Void
    let onReset: () -> Void
    let onClose: () -> Void

    @State private var draft: HomeFilters

    init(
        role: UserRole,
        initialFilters: HomeFilters,
        onApply: @escaping (HomeFilters) -> Void,
        onReset: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.role = role
        self.onApply = onApply
        self.onReset = onReset
        self.onClose = onClose
        _draft = State(initialValue: initialFilters)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            if role == .creator {
                                creatorFilters
                            } else {
                                brandFilters
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 140)
                    }
                }

                footer
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", action: onClose)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }

    private var creatorFilters: some View {
        VStack(alignment: .leading, spacing: 24) {
            filterSectionTitle("Minimum budget")

            HStack(spacing: 10) {
                ForEach(Self.budgetOptions, id: \.label) { option in
                    SelectableChip(
                        title: option.label,
                        selected: draft.minimumBrandBudget == option.value
                    ) {
                        draft.minimumBrandBudget = option.value
                    }
                }
            }

            filterSectionTitle("Campaign focus")

            chipGrid(
                options: Self.brandCampaignTagOptions,
                selected: draft.brandCampaignTags
            ) { selected in
                draft.brandCampaignTags = selected
            }
        }
    }

    private var brandFilters: some View {
        VStack(alignment: .leading, spacing: 24) {
            filterSectionTitle("Minimum followers")

            HStack(spacing: 10) {
                ForEach(Self.followerOptions, id: \.label) { option in
                    SelectableChip(
                        title: option.label,
                        selected: draft.minimumCreatorFollowers == option.value
                    ) {
                        draft.minimumCreatorFollowers = option.value
                    }
                }
            }

            filterSectionTitle("Minimum engagement rate")

            HStack(spacing: 10) {
                ForEach(Self.engagementOptions, id: \.label) { option in
                    SelectableChip(
                        title: option.label,
                        selected: draft.minimumCreatorEngagementRate == option.value
                    ) {
                        draft.minimumCreatorEngagementRate = option.value
                    }
                }
            }

            filterSectionTitle("Niche")

            chipGrid(
                options: Self.creatorNicheOptions,
                selected: draft.creatorNicheTags
            ) { selected in
                draft.creatorNicheTags = selected
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: {
                    draft = HomeFilters()
                    onReset()
                }) {
                    Text("Reset")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                }

                Button(action: { onApply(draft) }) {
                    Text("Apply")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.upsideGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 22)
            .background(
                Color.black.opacity(0.95)
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 0.5),
                        alignment: .top
                    )
            )
        }
    }

    private func filterSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white.opacity(0.82))
    }

    private func chipGrid(
        options: [String],
        selected: Set<String>,
        onChange: @escaping (Set<String>) -> Void
    ) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 95), spacing: 10)], spacing: 10) {
            ForEach(options, id: \.self) { option in
                SelectableChip(title: option, selected: selected.contains(option)) {
                    var updated = selected
                    if updated.contains(option) {
                        updated.remove(option)
                    } else {
                        updated.insert(option)
                    }
                    onChange(updated)
                }
            }
        }
    }

    private static let budgetOptions: [(label: String, value: Int?)] = [
        ("Any", nil),
        ("AED 1K+", 1_000),
        ("AED 2K+", 2_000)
    ]

    private static let followerOptions: [(label: String, value: Int?)] = [
        ("Any", nil),
        ("50K+", 50_000),
        ("100K+", 100_000),
        ("200K+", 200_000)
    ]

    private static let engagementOptions: [(label: String, value: Double?)] = [
        ("Any", nil),
        ("3%+", 3.0),
        ("4%+", 4.0),
        ("5%+", 5.0)
    ]

    private static let brandCampaignTagOptions: [String] = [
        "UGC", "Launch", "Lifestyle", "Beauty", "Fitness", "Music", "Tech"
    ]

    private static let creatorNicheOptions: [String] = [
        "Tech", "Product", "Fitness", "Lifestyle", "Travel", "Fashion", "Culture"
    ]
}

struct HomeProfileEditorSheet: View {
    let role: UserRole
    let onSave: (HomeProfileDraft) -> Void
    let onClose: () -> Void

    @State private var draft: HomeProfileDraft

    init(
        role: UserRole,
        initialProfile: HomeProfileDraft,
        onSave: @escaping (HomeProfileDraft) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.role = role
        self.onSave = onSave
        self.onClose = onClose
        _draft = State(initialValue: initialProfile)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        avatarHeader

                        Group {
                            ProfileEditorField(title: "Name", text: $draft.displayName)
                            ProfileEditorField(title: "Headline", text: $draft.headline)
                            ProfileEditorField(title: "Location", text: $draft.location)
                            ProfileEditorField(title: "Email", text: $draft.email, keyboardType: .emailAddress)
                            ProfileEditorField(
                                title: role == .creator ? "Handle" : "Website",
                                text: $draft.websiteOrHandle,
                                keyboardType: .URL
                            )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bio")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.78))

                            TextEditor(text: $draft.bio)
                                .frame(minHeight: 110)
                                .padding(8)
                                .scrollContentBackground(.hidden)
                                .foregroundColor(.white)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 140)
                }

                profileFooter
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", action: onClose)
                        .foregroundColor(.white.opacity(0.82))
                }
            }
        }
    }

    private var avatarHeader: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 62, height: 62)
                .overlay(
                    Text(draft.initials)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(role == .creator ? "Creator profile" : "Brand profile")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text("Update how you appear across matching and chat.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var profileFooter: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Text("Cancel")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.84))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
            }

            Button(action: { onSave(draft) }) {
                Text("Save")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.upsideGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 22)
        .background(
            Color.black.opacity(0.95)
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 0.5),
                    alignment: .top
                )
        )
    }
}

private struct ProfileEditorField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.78))

            TextField("", text: $text)
                .keyboardType(keyboardType)
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
        }
    }
}

private struct SelectableChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(selected ? .black : .white.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(selected ? Color.upsideGreen : Color.white.opacity(0.08))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(selected ? Color.upsideGreen : Color.white.opacity(0.18), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct SavedShortlistSheet: View {
    let cards: [HomeCard]
    let onMatch: (HomeCard) -> Void
    let onUnsave: (HomeCard) -> Void
    let onSkip: (HomeCard) -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if cards.isEmpty {
                    VStack(spacing: 10) {
                        Text("No saved cards")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        Text("Swipe up or tap the star to save opportunities here.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(cards, id: \.id) { card in
                                SavedCardRow(
                                    card: card,
                                    onMatch: { onMatch(card) },
                                    onUnsave: { onUnsave(card) },
                                    onSkip: { onSkip(card) }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 28)
                    }
                }
            }
            .navigationTitle("Saved")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", action: onClose)
                        .foregroundColor(.white.opacity(0.82))
                }
            }
        }
    }
}

private struct SavedCardRow: View {
    let card: HomeCard
    let onMatch: () -> Void
    let onUnsave: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                heroThumb

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                        .lineLimit(1)
                    Text(meta)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.58))
                        .lineLimit(2)
                }

                Spacer(minLength: 8)
            }

            HStack(spacing: 8) {
                shortlistActionButton(
                    title: "Skip",
                    titleColor: .red,
                    fill: Color.red.opacity(0.08),
                    stroke: Color.red.opacity(0.45),
                    action: onSkip
                )

                shortlistActionButton(
                    title: "Unsave",
                    titleColor: .white.opacity(0.88),
                    fill: Color.white.opacity(0.08),
                    stroke: Color.white.opacity(0.2),
                    action: onUnsave
                )

                shortlistActionButton(
                    title: "Match",
                    titleColor: .black,
                    fill: .upsideGreen,
                    stroke: .upsideGreen,
                    action: onMatch
                )
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var title: String {
        switch card {
        case .brand(let brand):
            return brand.name
        case .creator(let creator):
            return creator.handle
        }
    }

    private var subtitle: String {
        switch card {
        case .brand(let brand):
            return brand.campaign
        case .creator(let creator):
            return creator.niche
        }
    }

    private var meta: String {
        switch card {
        case .brand(let brand):
            return "\(brand.budget) • \(brand.deliverables)"
        case .creator(let creator):
            return "\(creator.followers) followers • \(creator.engagementRate)"
        }
    }

    private var heroThumb: some View {
        ZStack {
            if case .brand(let brand) = card,
               ["Sephora", "Allbirds", "Apple", "Nike"].contains(brand.name) {
                Color.white
            } else {
                Color.white.opacity(0.06)
            }

            Image(imageName)
                .resizable()
                .scaledToFit()
                .padding(8)
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }

    private var imageName: String {
        switch card {
        case .brand(let brand):
            return brand.imageName
        case .creator(let creator):
            return creator.imageName
        }
    }

    private func shortlistActionButton(
        title: String,
        titleColor: Color,
        fill: Color,
        stroke: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(titleColor)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(fill)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(stroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView(userRole: .creator, viewModel: HomeFeedViewModel(userRole: .creator))
}
