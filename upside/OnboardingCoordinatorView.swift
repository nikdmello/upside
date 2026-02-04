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
                    WelcomeView(onContinue: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            onboardingState.currentStep = .roleSelection
                        }
                    })
                    
                case .roleSelection:
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
                    
                case .auth:
                    AuthView(
                        userRole: onboardingState.selectedRole ?? .creator,
                        onAuthComplete: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                onboardingState.currentStep = .accountCreation
                            }
                        }
                    )
                    
                case .accountCreation:
                    VStack {
                        Text("Account Creation")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                        Text("Selected Role: \(onboardingState.selectedRole?.displayName ?? "None")")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.7))
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
        }
    }
}

#Preview {
    OnboardingCoordinatorView()
}