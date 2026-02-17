import SwiftUI

struct RoleSelectorView: View {
    @State private var selectedRole: UserRole?
    @State private var isAnimated = false
    let onRoleSelected: (UserRole) -> Void

    var body: some View {
        ZStack {
            OnboardingBackground(style: .subtle, isAnimated: isAnimated)

            VStack(spacing: 0) {
                OnboardingHeader(
                    title: "What are you\nhere to do?",
                    subtitle: "Choose your side of the marketplace"
                )
                .opacity(isAnimated ? 1 : 0)
                .offset(y: isAnimated ? 0 : -20)
                .animation(.easeOut(duration: 0.6).delay(0.2), value: isAnimated)
                .padding(.top, 80)
                .padding(.horizontal, OnboardingTheme.horizontalPadding)

                Spacer()

                VStack(spacing: 20) {
                    RoleCard(
                        role: .creator,
                        isSelected: selectedRole == .creator,
                        gradient: [Color.upsideGreen, Color.upsideGreen.opacity(0.7)],
                        onTap: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            selectedRole = .creator
                        }
                    )
                    .opacity(isAnimated ? 1 : 0)
                    .offset(x: isAnimated ? 0 : -50)
                    .animation(.easeOut(duration: 0.6).delay(0.4), value: isAnimated)

                    RoleCard(
                        role: .brand,
                        isSelected: selectedRole == .brand,
                        gradient: [Color.upsideGreen, Color.upsideGreen.opacity(0.7)],
                        onTap: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            selectedRole = .brand
                        }
                    )
                    .opacity(isAnimated ? 1 : 0)
                    .offset(x: isAnimated ? 0 : 50)
                    .animation(.easeOut(duration: 0.6).delay(0.6), value: isAnimated)
                }
                .padding(.horizontal, 24)

                Spacer()

                OnboardingPrimaryButton(
                    title: "Continue",
                    icon: "arrow.right",
                    isEnabled: selectedRole != nil,
                    action: {
                        guard let role = selectedRole else { return }
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        onRoleSelected(role)
                    }
                )
                .scaleEffect(isAnimated ? 1.0 : 0.9)
                .opacity(isAnimated ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(0.8), value: isAnimated)
                .padding(.horizontal, OnboardingTheme.horizontalPadding)
                .padding(.bottom, OnboardingTheme.bottomPadding)
            }
        }
        .onAppear {
            isAnimated = true
        }
    }
}

struct RoleCard: View {
    let role: UserRole
    let isSelected: Bool
    let gradient: [Color]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)

                    Image(systemName: role == .creator ? "person.fill" : "building.2.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("I'm a \(role.displayName)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Text(role == .creator ?
                         "I make content and work with brands" :
                         "I want to hire creators and run campaigns"
                    )
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.leading)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(isSelected ? Color.white : Color.clear)
                        .frame(width: 24, height: 24)

                    Circle()
                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .opacity(isSelected ? 0 : 1)

                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .opacity(isSelected ? 1 : 0)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(isSelected ? 0.12 : 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: isSelected ? gradient : [Color.white.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .shadow(
            color: isSelected ? gradient[0].opacity(0.3) : .clear,
            radius: 20, x: 0, y: 10
        )
        .animation(.easeInOut(duration: 0.3), value: isSelected)
    }
}

#Preview {
    RoleSelectorView(onRoleSelected: { _ in })
}
