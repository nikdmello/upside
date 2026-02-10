import SwiftUI

struct BrandProfileSetupFlow: View {
    @StateObject private var profileState = BrandProfileState()
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.02, green: 0.02, blue: 0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ProfileProgressBar(
                    currentStep: profileState.currentStep.stepNumber,
                    totalSteps: profileState.currentStep.totalSteps
                )
                .padding(.horizontal, 32)
                .padding(.top, 20)

                Group {
                    switch profileState.currentStep {
                    case .company:
                        BrandCompanyView(profileState: profileState)
                    case .budget:
                        BrandBudgetView(profileState: profileState)
                    case .goals:
                        BrandGoalsView(profileState: profileState)
                    case .finish:
                        BrandFinishView(onComplete: onComplete)
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer()

                if profileState.currentStep != .finish {
                    ProfileNavigationButtons(
                        canGoBack: profileState.canGoBack,
                        canGoNext: profileState.canGoNext,
                        onBack: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                profileState.previousStep()
                            }
                        },
                        onNext: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                profileState.nextStep()
                            }
                        }
                    )
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
                }
            }
        }
    }
}

#Preview {
    BrandProfileSetupFlow(onComplete: {})
}
