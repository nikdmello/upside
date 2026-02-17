import SwiftUI

struct WelcomeView: View {
    let showSplash: Bool
    let safeAreaTop: CGFloat
    let onSignUp: () -> Void
    let onLogin: () -> Void
    @State private var isAnimated = false

    var body: some View {
        GeometryReader { geo in
            let logoTopInset = BrandLogo.topInset(safeAreaTop: safeAreaTop)

            ZStack {
                WelcomeBackground(isAnimated: isAnimated)

                VStack(spacing: 0) {
                    Spacer().frame(height: logoTopInset + (BrandLogo.height * BrandLogo.scale))

                    Spacer()

                    VStack(spacing: 24) {
                        VStack(spacing: 14) {
                            VStack(spacing: 2) {
                                Text("Close deals")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .kerning(-0.2)

                                Text("with influence")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.upsideGreen.opacity(0.94))
                                    .kerning(-0.2)
                            }
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 320, alignment: .center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(minHeight: 92)
                            .padding(.bottom, 4)
                            .opacity(isAnimated ? 1 : 0)
                            .offset(y: isAnimated ? 0 : 20)
                            .animation(.easeOut(duration: 0.6).delay(0.4), value: isAnimated)

                            ZStack {
                                Text("Find partners. Stay compliant. Get paid.")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.clear)
                                    .modifier(SoftOutline(color: .white, width: 0.7, opacity: 0.52))

                                Text("Find partners. Stay compliant. Get paid.")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.12))
                            }
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300, alignment: .center)
                            .lineSpacing(1)
                            .opacity(isAnimated ? 1 : 0)
                            .offset(y: isAnimated ? 0 : 20)
                            .animation(.easeOut(duration: 0.6).delay(0.6), value: isAnimated)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 32)

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
                                .background(Color.upsideGreen)
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
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.86))
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 27)
                                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                )
                                .cornerRadius(27)
                        }
                        .scaleEffect(isAnimated ? 1.0 : 0.9)
                        .opacity(isAnimated ? 1 : 0)
                        .animation(.easeOut(duration: 0.6).delay(1.0), value: isAnimated)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                BrandLogoView()
                    .scaleEffect(BrandLogo.scale)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, logoTopInset)
                    .opacity(showSplash ? 0 : 1)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
        .ignoresSafeArea()
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
    WelcomeView(showSplash: false, safeAreaTop: 0, onSignUp: {}, onLogin: {})
}

struct WelcomeBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isAnimated: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            GeometryReader { geo in
                let t = timeline.date.timeIntervalSinceReferenceDate

                let beamAngle1 = -20 + (reduceMotion ? 0.0 : 8.0 * sin(t * 0.24))
                let beamAngle2 = 16 + (reduceMotion ? 0.0 : 9.0 * cos(t * 0.20))
                let beamAngle3 = -4 + (reduceMotion ? 0.0 : 7.0 * sin(t * 0.28))

                let x1 = 0.24 + (reduceMotion ? 0.0 : 0.10 * sin(t * 0.42))
                let y1 = 0.15 + (reduceMotion ? 0.0 : 0.08 * cos(t * 0.34))
                let x2 = 0.72 + (reduceMotion ? 0.0 : 0.12 * cos(t * 0.30))
                let y2 = 0.21 + (reduceMotion ? 0.0 : 0.10 * sin(t * 0.38))

                ZStack {
                    Color.black
                        .ignoresSafeArea()

                    spotlightBeam(
                        size: CGSize(width: geo.size.width * 0.34, height: geo.size.height * 1.02),
                        angle: beamAngle1,
                        xOffset: -geo.size.width * 0.14,
                        opacity: 0.14
                    )

                    spotlightBeam(
                        size: CGSize(width: geo.size.width * 0.36, height: geo.size.height * 1.02),
                        angle: beamAngle2,
                        xOffset: geo.size.width * 0.16,
                        opacity: 0.13
                    )

                    spotlightBeam(
                        size: CGSize(width: geo.size.width * 0.30, height: geo.size.height * 0.98),
                        angle: beamAngle3,
                        xOffset: 0,
                        opacity: 0.09
                    )

                    spotlight(
                        center: UnitPoint(x: x1, y: y1),
                        startRadius: 32,
                        endRadius: 340,
                        opacity: 0.09,
                        blurRadius: 12
                    )

                    spotlight(
                        center: UnitPoint(x: x2, y: y2),
                        startRadius: 40,
                        endRadius: 390,
                        opacity: 0.07,
                        blurRadius: 16
                    )

                    // Keep top area dark so spotlights feel like beams, not a green wash.
                    LinearGradient(
                        colors: [Color.black.opacity(0.44), Color.black.opacity(0.12), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea()

                    LinearGradient(
                        colors: [Color.black.opacity(0.0), Color.black.opacity(0.55)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            }
        }
        .opacity(isAnimated ? 1 : 0)
        .animation(.easeOut(duration: 0.9), value: isAnimated)
    }

    private func spotlightBeam(
        size: CGSize,
        angle: Double,
        xOffset: CGFloat,
        opacity: Double
    ) -> some View {
        BeamShape()
            .fill(
                LinearGradient(
                    colors: [
                        Color.upsideGreen.opacity(opacity),
                        Color.upsideGreen.opacity(opacity * 0.35),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: size.width, height: size.height)
            .rotationEffect(.degrees(angle), anchor: .top)
            .offset(x: xOffset, y: -size.height * 0.42)
            .blur(radius: 12)
            .blendMode(.screen)
            .ignoresSafeArea()
    }

    private func spotlight(
        center: UnitPoint,
        startRadius: CGFloat,
        endRadius: CGFloat,
        opacity: Double,
        blurRadius: CGFloat
    ) -> some View {
        RadialGradient(
            colors: [Color.upsideGreen.opacity(opacity), Color.clear],
            center: center,
            startRadius: startRadius,
            endRadius: endRadius
        )
        .blendMode(.screen)
        .blur(radius: blurRadius)
        .ignoresSafeArea()
    }
}

private struct BeamShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let top = CGPoint(x: rect.midX, y: 0)
        let right = CGPoint(x: rect.maxX, y: rect.maxY)
        let left = CGPoint(x: rect.minX, y: rect.maxY)

        path.move(to: top)
        path.addLine(to: right)
        path.addLine(to: left)
        path.closeSubpath()
        return path
    }
}

private struct SoftOutline: ViewModifier {
    let color: Color
    let width: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(opacity), radius: 0, x: width, y: 0)
            .shadow(color: color.opacity(opacity), radius: 0, x: -width, y: 0)
            .shadow(color: color.opacity(opacity), radius: 0, x: 0, y: width)
            .shadow(color: color.opacity(opacity), radius: 0, x: 0, y: -width)
            .shadow(color: color.opacity(opacity * 0.75), radius: 0, x: width, y: width)
            .shadow(color: color.opacity(opacity * 0.75), radius: 0, x: -width, y: -width)
            .shadow(color: color.opacity(opacity * 0.75), radius: 0, x: width, y: -width)
            .shadow(color: color.opacity(opacity * 0.75), radius: 0, x: -width, y: width)
    }
}
