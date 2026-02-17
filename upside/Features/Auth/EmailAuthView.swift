import SwiftUI

struct EmailAuthView: View {
    @StateObject private var authManager = AuthManager()
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var isAnimated = false
    let onAuthComplete: () -> Void

    var body: some View {
        ZStack {
            OnboardingBackground(style: .subtle, isAnimated: isAnimated)

            VStack(spacing: 0) {
                OnboardingHeader(
                    title: "Sign in with\nemail",
                    subtitle: "Use your email and password"
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

                    ZStack {
                        OnboardingPrimaryButton(
                            title: isLoading ? "Signing In..." : "Sign In",
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
                onAuthComplete()
            }
        }
    }

    private func signIn() {
        isLoading = true
        authManager.signInWithEmail(email, password: password)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isLoading = false
        }
    }
}

#Preview {
    EmailAuthView(onAuthComplete: {})
}
