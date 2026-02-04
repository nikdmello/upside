import SwiftUI

struct WelcomeView: View {
    let onSignUp: () -> Void
    let onLogin: () -> Void
    @State private var isAnimated = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.05, green: 0.05, blue: 0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 32) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple, Color.blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .scaleEffect(isAnimated ? 1.0 : 0.8)
                            .animation(.easeOut(duration: 0.8).delay(0.2), value: isAnimated)
                        
                        Text("U")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 16) {
                        Text("Get paid for\nyour influence.")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .opacity(isAnimated ? 1 : 0)
                            .offset(y: isAnimated ? 0 : 20)
                            .animation(.easeOut(duration: 0.6).delay(0.4), value: isAnimated)
                        
                        Text("Match with brands. Stay compliant.\nGet deals done fast.")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .opacity(isAnimated ? 1 : 0)
                            .offset(y: isAnimated ? 0 : 20)
                            .animation(.easeOut(duration: 0.6).delay(0.6), value: isAnimated)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        onSignUp()
                    }) {
                        Text("Create Account")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(
                                LinearGradient(
                                    colors: [Color.white, Color.gray.opacity(0.9)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(30)
                            .shadow(color: .white.opacity(0.3), radius: 20, x: 0, y: 10)
                    }
                    .scaleEffect(isAnimated ? 1.0 : 0.9)
                    .opacity(isAnimated ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.8), value: isAnimated)
                    
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        onLogin()
                    }) {
                        Text("Sign In")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .scaleEffect(isAnimated ? 1.0 : 0.9)
                    .opacity(isAnimated ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(1.0), value: isAnimated)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            isAnimated = true
        }
    }
}

#Preview {
    WelcomeView(onSignUp: {}, onLogin: {})
}