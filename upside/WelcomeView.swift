import SwiftUI

struct WelcomeView: View {
    let showSplash: Bool
    let onSignUp: () -> Void
    let onLogin: () -> Void
    @State private var isAnimated = false
    var body: some View {
        GeometryReader { geo in
            let topY = BrandLogo.topY(safeAreaTop: geo.safeAreaInsets.top)

            ZStack {
                RadialGradient(
                    colors: [
                        Color.upsideGreen.opacity(0.12),
                        Color.black
                    ],
                    center: .top,
                    startRadius: 60,
                    endRadius: 520
                )
                .ignoresSafeArea()
                .overlay(
                    Color.black.opacity(0.92)
                        .ignoresSafeArea()
                )

                VStack(spacing: 0) {
                    Spacer().frame(height: BrandLogo.topPadding + geo.safeAreaInsets.top + (BrandLogo.height * BrandLogo.scale))

                    Spacer()

                    VStack(spacing: 32) {
                        VStack(spacing: 16) {
                            Text("Close deals with\ninfluence")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .opacity(isAnimated ? 1 : 0)
                                .offset(y: isAnimated ? 0 : 20)
                                .animation(.easeOut(duration: 0.6).delay(0.4), value: isAnimated)

                            Text("Discover partners. Stay compliant. Get paid faster.")
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
                            Text("Get Started")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(
                                    Color.upsideGreen
                                )
                                .cornerRadius(30)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 30)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                                .shadow(color: Color.upsideGreen.opacity(0.45), radius: 24, x: 0, y: 14)
                                .shadow(color: .black.opacity(0.6), radius: 14, x: 0, y: 8)
                        }
                        .scaleEffect(isAnimated ? 1.0 : 0.96)
                        .opacity(isAnimated ? 1 : 0)
                        .animation(.easeOut(duration: 0.6).delay(0.8), value: isAnimated)

                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            onLogin()
                        }) {
                        Text("Sign in")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                        }
                        .scaleEffect(isAnimated ? 1.0 : 0.9)
                        .opacity(isAnimated ? 1 : 0)
                        .animation(.easeOut(duration: 0.6).delay(1.0), value: isAnimated)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
                }

                UpsideLogo()
                    .frame(height: BrandLogo.height)
                    .scaleEffect(BrandLogo.scale)
                    .position(x: geo.size.width / 2, y: topY)
            }
        }
        .onAppear {
            if !showSplash {
                isAnimated = true
            }
        }
        .onChange(of: showSplash) { _, newValue in
            if newValue == false {
                isAnimated = true
            }
        }
    }
}

#Preview {
    WelcomeView(showSplash: false, onSignUp: {}, onLogin: {})
}
