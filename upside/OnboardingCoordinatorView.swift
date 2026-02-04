import SwiftUI

struct OnboardingCoordinatorView: View {
    @StateObject private var onboardingState = OnboardingState()
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.05, green: 0.05, blue: 0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            Group {
                switch onboardingState.currentStep {
                case .welcome:
                    WelcomeView(
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
                        onAuthComplete: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                onboardingState.selectedRole = .creator
                                onboardingState.currentStep = .accountCreation
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    onboardingState.showNotificationSheet = true
                                }
                            }
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
                            onboardingState.selectRole(role)
                        }
                    })
                    
                case .auth:
                    AuthView(
                        userRole: onboardingState.selectedRole,
                        isLogin: false,
                        onAuthComplete: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                onboardingState.currentStep = .accountCreation
                            }
                        }
                    )
                    
                case .accountCreation:
                    VStack(spacing: 0) {
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.green, Color.blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                    }
                    .sheet(isPresented: $onboardingState.showNotificationSheet) {
                        NotificationPermissionSheet(
                            isPresented: $onboardingState.showNotificationSheet,
                            userRole: onboardingState.selectedRole ?? .creator,
                            onComplete: {
                                onboardingState.completeNotifications()
                            }
                        )
                    }
                    
                default:
                    VStack {
                        Text("Coming Soon")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                        Text("Step: \(String(describing: onboardingState.currentStep))")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.7))
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
    OnboardingCoordinatorView()
}