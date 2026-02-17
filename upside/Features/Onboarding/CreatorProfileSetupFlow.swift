import SwiftUI

struct CreatorProfileSetupFlow: View {
    @StateObject private var profileState = CreatorProfileState()
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            OnboardingBackground(style: .subtle)

            VStack(spacing: 0) {
                // Progress indicator
                ProfileProgressBar(
                    currentStep: profileState.currentStep.stepNumber,
                    totalSteps: profileState.currentStep.totalSteps
                )
                .padding(.horizontal, 32)
                .padding(.top, 20)

                // Step content
                Group {
                    switch profileState.currentStep {
                    case .name:
                        CreatorNameView(profileState: profileState)
                    case .audience:
                        CreatorAudienceView(profileState: profileState)
                    case .rate:
                        CreatorRateView(profileState: profileState)
                    case .finish:
                        CreatorFinishView(onComplete: onComplete)
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer()

                // Navigation buttons
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
    CreatorProfileSetupFlow(onComplete: {})
}
