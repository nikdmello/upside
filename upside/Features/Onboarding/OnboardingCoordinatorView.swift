import SwiftUI

struct OnboardingCoordinatorView: View {
    let showSplash: Bool
    let safeAreaTop: CGFloat
    @ObservedObject var appSession: AppSessionStore
    @StateObject private var onboardingState = OnboardingState()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.02, green: 0.02, blue: 0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Group {
                switch onboardingState.currentStep {
                case .welcome:
                    WelcomeView(
                        showSplash: showSplash,
                        safeAreaTop: safeAreaTop,
                        onSignUp: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                onboardingState.startSignUp()
                            }
                        },
                        onLogin: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                onboardingState.startLogin()
                            }
                        }
                    )

                case .login:
                    AuthView(
                        userRole: nil,
                        isLogin: true,
                        supportingMessage: nil,
                        onAuthComplete: { user in
                            appSession.completeSignIn(role: .creator, user: user)
                            onboardingState.selectedRole = .creator
                        },
                        onDemoLogin: { role in
                            appSession.completeSignIn(role: role, user: nil)
                            onboardingState.selectedRole = role
                        }
                    )

                case .signUp:
                    RoleSelectorView(onRoleSelected: { role in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            onboardingState.selectRole(role)
                        }
                    })
                    .sheet(isPresented: $onboardingState.showNotificationSheet) {
                        NotificationPermissionSheet(
                            isPresented: $onboardingState.showNotificationSheet,
                            userRole: onboardingState.selectedRole ?? .creator,
                            onComplete: {
                                onboardingState.completeNotifications()
                            }
                        )
                    }

                case .roleSelection:
                    RoleSelectorView(onRoleSelected: { role in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            onboardingState.selectedRole = role
                            onboardingState.currentStep = .auth
                        }
                    })

                case .auth:
                    AuthView(
                        userRole: onboardingState.selectedRole,
                        isLogin: false,
                        supportingMessage: nil,
                        onAuthComplete: { user in
                            let role = onboardingState.selectedRole ?? .creator
                            appSession.completeSignIn(role: role, user: user)
                        },
                        onDemoLogin: { role in
                            appSession.completeSignIn(role: role, user: nil)
                            onboardingState.selectedRole = role
                        }
                    )

                case .accountCreation:
                    VStack(spacing: 0) {
                        Spacer()

                        ZStack {
                            Circle()
                                .fill(Color.upsideGreen)
                                .frame(width: 80, height: 80)

                            Image(systemName: "checkmark")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Spacer()
                    }

                case .creatorProfile:
                    CreatorProfileSetupFlow {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            onboardingState.currentStep = .confirmation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                onboardingState.showNotificationSheet = true
                            }
                        }
                    }

                case .brandProfile:
                    BrandProfileSetupFlow {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            onboardingState.currentStep = .confirmation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                onboardingState.showNotificationSheet = true
                            }
                        }
                    }

                case .confirmation:
                    HomeTabShellView(
                        userRole: onboardingState.selectedRole ?? .creator,
                        onSignOut: {
                            appSession.signOut()
                            onboardingState.selectedRole = nil
                            onboardingState.showNotificationSheet = false
                            onboardingState.isLoginFlow = false
                            onboardingState.currentStep = .welcome
                        }
                    )
                        .sheet(isPresented: $onboardingState.showNotificationSheet) {
                            NotificationPermissionSheet(
                                isPresented: $onboardingState.showNotificationSheet,
                                userRole: onboardingState.selectedRole ?? .creator,
                                onComplete: {
                                    onboardingState.completeNotifications()
                                }
                            )
                        }
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            if onboardingState.previousStep != nil {
                VStack {
                    HStack {
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            withAnimation(.easeInOut(duration: 0.3)) {
                                onboardingState.goBack()
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                                .frame(width: 44, height: 44)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 80)

                    Spacer()
                }
            }

        }
    }
}

#Preview {
    OnboardingCoordinatorView(showSplash: false, safeAreaTop: 0, appSession: AppSessionStore.shared)
}
