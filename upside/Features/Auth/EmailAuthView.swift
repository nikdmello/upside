import SwiftUI

struct EmailAuthView: View {
    @StateObject private var authManager = AuthManager()
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var isAnimated = false
    let isLogin: Bool
    let onAuthComplete: (User?) -> Void

    private var title: String {
        isLogin ? "Sign in with\nemail" : "Create account\nwith email"
    }

    private var subtitle: String {
        isLogin ? "Use your email and password" : "Use your email and password to continue"
    }

    private var actionTitle: String {
        isLogin ? "Sign In" : "Continue"
    }

    var body: some View {
        ZStack {
            OnboardingBackground(style: .subtle, isAnimated: isAnimated)

            VStack(spacing: 0) {
                OnboardingHeader(
                    title: title,
                    subtitle: subtitle
                )
                .opacity(isAnimated ? 1 : 0)
                .offset(y: isAnimated ? 0 : -20)
                .animation(.easeOut(duration: 0.6).delay(0.2), value: isAnimated)
                .padding(.top, 80)
                .padding(.horizontal, OnboardingTheme.horizontalPadding)

                Spacer()

                VStack(spacing: 20) {
                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .textFieldStyle(OnboardingTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)

                        SecureField("Password", text: $password)
                            .textFieldStyle(OnboardingTextFieldStyle())
                    }
                    .opacity(isAnimated ? 1 : 0)
                    .offset(y: isAnimated ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.4), value: isAnimated)

                    VStack(spacing: 12) {
                        ZStack {
                            OnboardingPrimaryButton(
                                title: isLoading ? "\(actionTitle)..." : actionTitle,
                                isEnabled: !(email.isEmpty || password.isEmpty || isLoading),
                                action: {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    signIn()
                                }
                            )

                            if isLoading {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                        .scaleEffect(0.8)
                                        .padding(.trailing, 24)
                                }
                            }
                        }

                        if let authError = authManager.authError {
                            Text(authError)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.red.opacity(0.9))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .opacity(isAnimated ? 1 : 0)
                    .offset(y: isAnimated ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.6), value: isAnimated)
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
                isLoading = false
                onAuthComplete(authManager.user)
            }
        }
        .onChange(of: authManager.authError) { _, _ in
            isLoading = false
        }
    }

    private func signIn() {
        isLoading = true
        authManager.signInWithEmail(email, password: password)
    }
}

#Preview {
    EmailAuthView(isLogin: true, onAuthComplete: { _ in })
}
