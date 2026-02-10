import SwiftUI

struct BrandCompanyView: View {
    @ObservedObject var profileState: BrandProfileState
    @State private var isAnimated = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 48) {
                VStack(spacing: 12) {
                    Text("What's your company?")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(isAnimated ? 1 : 0)
                        .offset(y: isAnimated ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: isAnimated)

                    Text("We'll use this to personalize your experience")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .opacity(isAnimated ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: isAnimated)
                }

                VStack(spacing: 12) {
                    TextField("Company name", text: $profileState.profile.companyName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 0)
                        .padding(.vertical, 16)
                        .background(Color.clear)

                    Rectangle()
                        .fill(
                            profileState.profile.companyName.isEmpty ?
                            Color.white.opacity(0.2) :
                            Color.upsideGreen
                        )
                        .frame(height: 2)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: profileState.profile.companyName.isEmpty)
                }
                    .opacity(isAnimated ? 1 : 0)
                    .offset(y: isAnimated ? 0 : 30)
                    .animation(.easeOut(duration: 0.6).delay(0.4), value: isAnimated)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .onAppear {
            isAnimated = true
        }
    }
}

struct BrandBudgetView: View {
    @ObservedObject var profileState: BrandProfileState
    @State private var isAnimated = false
    @State private var sliderValue: Double = 10000

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 48) {
                VStack(spacing: 12) {
                    Text("What's your budget?")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(isAnimated ? 1 : 0)
                        .offset(y: isAnimated ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: isAnimated)

                    Text("Per campaign")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .opacity(isAnimated ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: isAnimated)
                }

                VStack(spacing: 32) {
                    Text("\(formatBudget(Int(sliderValue)))")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                        .opacity(isAnimated ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: isAnimated)

                    VStack(spacing: 16) {
                        Slider(value: $sliderValue, in: 1000...100000, step: 1000)
                            .accentColor(Color.upsideGreen)
                            .onChange(of: sliderValue) {
                                profileState.profile.campaignBudget = formatBudget(Int(sliderValue))
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            }

                        HStack {
                            Text("$1K")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))

                            Spacer()

                            Text("$100K+")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .opacity(isAnimated ? 1 : 0)
                    .offset(y: isAnimated ? 0 : 30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: isAnimated)
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .background(Color.black)
        .onAppear {
            isAnimated = true
            if let currentBudget = extractBudgetValue(profileState.profile.campaignBudget) {
                sliderValue = Double(currentBudget)
            }
        }
    }

    private func formatBudget(_ value: Int) -> String {
        if value >= 100000 {
            return "$100K+"
        } else if value >= 1000 {
            return "$\(value / 1000)K"
        } else {
            return "$\(value)"
        }
    }

    private func extractBudgetValue(_ budgetString: String) -> Int? {
        if budgetString.contains("100K+") { return 100000 }
        if budgetString.contains("K") {
            let number = budgetString.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: "K", with: "")
            return (Int(number) ?? 10) * 1000
        }
        return nil
    }
}

struct BrandGoalsView: View {
    @ObservedObject var profileState: BrandProfileState
    @State private var isAnimated = false

    private let goalOptions = [
        "Increase brand awareness",
        "Drive website traffic",
        "Boost product sales",
        "Launch new product",
        "Reach younger audience",
        "Build brand community"
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 48) {
                VStack(spacing: 12) {
                    Text("What's your goal?")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(isAnimated ? 1 : 0)
                        .offset(y: isAnimated ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: isAnimated)

                    Text("Choose your main objective")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .opacity(isAnimated ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: isAnimated)
                }

                VStack(spacing: 12) {
                    ForEach(Array(goalOptions.enumerated()), id: \.offset) { index, goal in
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            profileState.profile.targetAudience = goal
                        }) {
                            HStack {
                                Text(goal)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)

                                Spacer()

                                if profileState.profile.targetAudience == goal {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color.upsideGreen)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 18)
                            .background(
                                profileState.profile.targetAudience == goal ?
                                Color.white.opacity(0.08) : Color.white.opacity(0.03)
                            )
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        profileState.profile.targetAudience == goal ?
                                        Color.upsideGreen : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                        }
                        .opacity(isAnimated ? 1 : 0)
                        .offset(y: isAnimated ? 0 : 30)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3 + Double(index) * 0.05), value: isAnimated)
                    }
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .background(Color.black)
        .onAppear {
            isAnimated = true
        }
    }
}

struct BrandFinishView: View {
    let onComplete: () -> Void
    @State private var isAnimated = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 40) {
                ZStack {
                    Circle()
                        .fill(Color.upsideGreen)
                        .frame(width: 120, height: 120)
                        .scaleEffect(isAnimated ? 1.0 : 0.8)
                        .animation(.easeOut(duration: 0.8).delay(0.2), value: isAnimated)

                    Image(systemName: "checkmark")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(spacing: 16) {
                    Text("You're all set!")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(isAnimated ? 1 : 0)
                        .offset(y: isAnimated ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.4), value: isAnimated)

                    Text("Start discovering creators\nwho match your brand")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .opacity(isAnimated ? 1 : 0)
                        .offset(y: isAnimated ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.6), value: isAnimated)
                }

                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    onComplete()
                }) {
                    Text("Let's Go!")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color.upsideGreen)
                        .cornerRadius(30)
                        .shadow(color: .white.opacity(0.3), radius: 20, x: 0, y: 10)
                }
                .scaleEffect(isAnimated ? 1.0 : 0.9)
                .opacity(isAnimated ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(0.8), value: isAnimated)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .onAppear {
            isAnimated = true
        }
    }
}

#Preview {
    BrandCompanyView(profileState: BrandProfileState())
        .background(Color.black)
}
