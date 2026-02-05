import SwiftUI

struct CreatorNameView: View {
    @ObservedObject var profileState: CreatorProfileState
    @State private var isAnimated = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 48) {
                VStack(spacing: 12) {
                    Text("What's your name?")
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
                    TextField("Enter your full name", text: $profileState.profile.fullName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 0)
                        .padding(.vertical, 16)
                        .background(Color.clear)
                    
                    Rectangle()
                        .fill(
                            profileState.profile.fullName.isEmpty ? 
                            Color.white.opacity(0.2) : 
                            Color.upsideGreen
                        )
                        .frame(height: 2)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: profileState.profile.fullName.isEmpty)
                }
                .opacity(isAnimated ? 1 : 0)
                .offset(y: isAnimated ? 0 : 30)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: isAnimated)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .background(Color.black)
        .onAppear {
            isAnimated = true
        }
    }
}

struct CreatorAudienceView: View {
    @ObservedObject var profileState: CreatorProfileState
    @State private var isAnimated = false
    
    private let audienceOptions = [
        "1K - 10K", "10K - 50K", "50K - 100K", 
        "100K - 500K", "500K - 1M", "1M+"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 48) {
                VStack(spacing: 12) {
                    Text("How big is your audience?")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(isAnimated ? 1 : 0)
                        .offset(y: isAnimated ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: isAnimated)
                    
                    Text("This helps brands find the right match")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .opacity(isAnimated ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: isAnimated)
                }
                
                VStack(spacing: 12) {
                    ForEach(Array(audienceOptions.enumerated()), id: \.offset) { index, option in
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            profileState.profile.followerCount = option
                        }) {
                            HStack {
                                Text(option)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                if profileState.profile.followerCount == option {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color.upsideGreen)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 18)
                            .background(
                                profileState.profile.followerCount == option ?
                                Color.white.opacity(0.08) : Color.white.opacity(0.03)
                            )
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        profileState.profile.followerCount == option ?
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

struct CreatorRateView: View {
    @ObservedObject var profileState: CreatorProfileState
    @State private var isAnimated = false
    @State private var sliderValue: Double = 500
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 48) {
                VStack(spacing: 12) {
                    Text("What's your rate?")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(isAnimated ? 1 : 0)
                        .offset(y: isAnimated ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: isAnimated)
                    
                    Text("Per Instagram post")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .opacity(isAnimated ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: isAnimated)
                }
                
                VStack(spacing: 32) {
                    Text("$\(Int(sliderValue))")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                        .opacity(isAnimated ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: isAnimated)
                    
                    VStack(spacing: 16) {
                        Slider(value: $sliderValue, in: 50...2000, step: 50)
                            .accentColor(Color.upsideGreen)
                            .onChange(of: sliderValue) {
                                profileState.profile.baseRate = String(Int(sliderValue))
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            }
                        
                        HStack {
                            Text("$50")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Spacer()
                            
                            Text("$2000")
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
            if let currentRate = Double(profileState.profile.baseRate), currentRate > 0 {
                sliderValue = currentRate
            }
        }
    }
}

struct CreatorFinishView: View {
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
                    
                    Text("Start connecting with brands\nin the GCC")
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
    CreatorNameView(profileState: CreatorProfileState())
        .background(Color.black)
}