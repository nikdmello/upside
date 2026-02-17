import SwiftUI

// MARK: - Progress Bar Component
struct ProfileProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Step \(currentStep) of \(totalSteps)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 4)

                    // Progress fill
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.upsideGreen)
                        .frame(width: geometry.size.width * (CGFloat(currentStep) / CGFloat(totalSteps)), height: 4)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Navigation Buttons Component
struct ProfileNavigationButtons: View {
    let canGoBack: Bool
    let canGoNext: Bool
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            if canGoBack {
                OnboardingSecondaryButton(
                    title: "Back",
                    action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        onBack()
                    }
                )
            }

            OnboardingPrimaryButton(
                title: "Continue",
                isEnabled: canGoNext,
                action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    onNext()
                }
            )
        }
    }
}

// MARK: - Input Field Component
struct ProfileInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)

            TextField(placeholder, text: $text)
                .textFieldStyle(OnboardingTextFieldStyle())
                .keyboardType(keyboardType)
        }
    }
}
