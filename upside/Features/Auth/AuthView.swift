import SwiftUI
import AuthenticationServices

struct AuthView: View {
    let userRole: UserRole?
    let isLogin: Bool
    let onAuthComplete: () -> Void
    let onDemoLogin: ((UserRole) -> Void)?
    @State private var isAnimated = false
    @State private var showEmailAuth = false
    @StateObject private var authManager = AuthManager()
    @State private var isDemoLogin = false
    @State private var demoRole: UserRole = .creator
    @State private var demoDragX: CGFloat = 0
    @State private var demoLockedRole: UserRole?

    private var headerTitle: String {
        isLogin ? "Welcome back" : "Create your\naccount"
    }

    private var headerSubtitle: String {
        isLogin
            ? "Sign in to continue"
            : "Join as a \(userRole?.displayName.lowercased() ?? "user") and start connecting"
    }

    var body: some View {
        ZStack {
            OnboardingBackground(style: .subtle, isAnimated: isAnimated)

            VStack(spacing: 0) {
                OnboardingHeader(title: headerTitle, subtitle: headerSubtitle)
                    .opacity(isAnimated ? 1 : 0)
                    .offset(y: isAnimated ? 0 : -20)
                    .animation(.easeOut(duration: 0.6).delay(0.2), value: isAnimated)
                .padding(.top, 80)
                .padding(.horizontal, OnboardingTheme.horizontalPadding)

                Spacer()

                VStack(spacing: 16) {
                    AppleSignInButton(
                        onTap: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            authManager.signInWithApple()
                        }
                    )
                    .opacity(isAnimated ? 1 : 0)
                    .offset(y: isAnimated ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.6), value: isAnimated)

                    GoogleSignInButton(
                        onTap: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            authManager.signInWithGoogle()
                        }
                    )
                    .opacity(isAnimated ? 1 : 0)
                    .offset(y: isAnimated ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.8), value: isAnimated)

                    AuthButton(
                        title: "Continue with Email",
                        icon: "envelope.fill",
                        backgroundColor: Color.upsideGreen,
                        foregroundColor: .black,
                        onTap: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            showEmailAuth = true
                        }
                    )
                    .opacity(isAnimated ? 1 : 0)
                    .offset(y: isAnimated ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(1.0), value: isAnimated)

                    #if DEBUG
                    AuthButton(
                        title: "Demo Login",
                        icon: "hammer.fill",
                        backgroundColor: Color.upsideGreen.opacity(0.2),
                        foregroundColor: Color.upsideGreen,
                        onTap: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            isDemoLogin = true
                            authManager.signInDemo()
                        }
                    )
                    .overlay {
                        GeometryReader { geo in
                            let width = geo.size.width
                            let maxOffset = width * 0.18
                            let clamped = max(min(demoDragX, maxOffset), -maxOffset)
                            let progress = abs(clamped) / maxOffset
                            let lockedOffset = demoLockedRole == .brand ? maxOffset : (demoLockedRole == .creator ? -maxOffset : clamped)

                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.06 + 0.18 * progress),
                                            Color.white.opacity(0.02)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                                        .stroke(Color.white.opacity(0.12 + 0.25 * progress), lineWidth: 1)
                                )
                                .blur(radius: 0.5)
                                .offset(x: lockedOffset)
                                .mask(
                                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                                        .frame(width: width * 0.55)
                                        .offset(x: lockedOffset)
                                )
                                .animation(.spring(response: 0.32, dampingFraction: 0.85), value: demoDragX)
                                .animation(.spring(response: 0.32, dampingFraction: 0.85), value: demoLockedRole)
                        }
                    }
                    .overlay(
                        HStack {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.4))
                            Text("Creator")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text("Brand")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 66)
                    )
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 8)
                            .onEnded { value in
                                let width = value.translation.width
                                let threshold: CGFloat = 32

                                if width <= -threshold {
                                    demoLockedRole = .creator
                                } else if width >= threshold {
                                    demoLockedRole = .brand
                                } else {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                                        demoDragX = 0
                                    }
                                    return
                                }

                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()

                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                    demoRole = demoLockedRole ?? .creator
                                    isDemoLogin = true
                                    authManager.signInDemo()
                                }
                            }
                            .onChanged { value in
                                let maxOffset: CGFloat = 80
                                demoDragX = max(min(value.translation.width, maxOffset), -maxOffset)
                            }
                    )
                    .onChange(of: isDemoLogin) { _, newValue in
                        if newValue == false {
                            demoDragX = 0
                            demoLockedRole = nil
                        }
                    }
                    .opacity(isAnimated ? 1 : 0)
                    .offset(y: isAnimated ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(1.2), value: isAnimated)
                    #endif
                }
                .padding(.horizontal, OnboardingTheme.horizontalPadding)
                .padding(.bottom, OnboardingTheme.bottomPadding)
            }
        }
        .onAppear {
            isAnimated = true
        }
        .onChange(of: authManager.isAuthenticated) { _, authenticated in
            if authenticated {
                if isDemoLogin, let onDemoLogin {
                    onDemoLogin(demoRole)
                } else {
                    onAuthComplete()
                }
            }
        }
        .sheet(isPresented: $showEmailAuth) {
            EmailAuthView(onAuthComplete: {
                showEmailAuth = false
                onAuthComplete()
            })
        }
    }
}

struct GoogleSignInButton: View {
    let onTap: () -> Void

    var body: some View {
        OnboardingSocialButton(
            title: "Continue with Google",
            assetIcon: "GoogleG",
            action: onTap
        )
    }
}

struct AppleSignInButton: View {
    let onTap: () -> Void

    var body: some View {
        OnboardingSocialButton(
            title: "Continue with Apple",
            systemIcon: "apple.logo",
            action: onTap
        )
    }
}

struct AuthButton: View {
    let title: String
    let icon: String
    let backgroundColor: Color
    let foregroundColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))

                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: OnboardingTheme.secondaryButtonHeight)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: OnboardingTheme.socialButtonCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: OnboardingTheme.socialButtonCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
    }
}

#Preview {
    AuthView(userRole: .creator, isLogin: false, onAuthComplete: {}, onDemoLogin: nil)
}
