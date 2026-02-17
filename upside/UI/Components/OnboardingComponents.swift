import SwiftUI

enum OnboardingBackgroundStyle {
    case hero
    case subtle
}

struct OnboardingBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let style: OnboardingBackgroundStyle
    let isAnimated: Bool

    init(style: OnboardingBackgroundStyle = .subtle, isAnimated: Bool = true) {
        self.style = style
        self.isAnimated = isAnimated
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            GeometryReader { geo in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let glowStrength = style == .hero ? 1.0 : 0.55
                let beamStrength = style == .hero ? 1.0 : 0.65

                let beamAngle1 = -20 + (reduceMotion ? 0.0 : 8.0 * sin(t * 0.24))
                let beamAngle2 = 16 + (reduceMotion ? 0.0 : 9.0 * cos(t * 0.20))
                let beamAngle3 = -4 + (reduceMotion ? 0.0 : 7.0 * sin(t * 0.28))

                let x1 = 0.24 + (reduceMotion ? 0.0 : 0.10 * sin(t * 0.42))
                let y1 = 0.14 + (reduceMotion ? 0.0 : 0.08 * cos(t * 0.34))
                let x2 = 0.72 + (reduceMotion ? 0.0 : 0.12 * cos(t * 0.30))
                let y2 = 0.20 + (reduceMotion ? 0.0 : 0.10 * sin(t * 0.38))

                ZStack {
                    Color.black
                        .ignoresSafeArea()

                    spotlightBeam(
                        size: CGSize(width: geo.size.width * 0.34, height: geo.size.height * 1.02),
                        angle: beamAngle1,
                        xOffset: -geo.size.width * 0.14,
                        opacity: 0.14 * beamStrength
                    )

                    spotlightBeam(
                        size: CGSize(width: geo.size.width * 0.36, height: geo.size.height * 1.02),
                        angle: beamAngle2,
                        xOffset: geo.size.width * 0.16,
                        opacity: 0.13 * beamStrength
                    )

                    spotlightBeam(
                        size: CGSize(width: geo.size.width * 0.30, height: geo.size.height * 0.98),
                        angle: beamAngle3,
                        xOffset: 0,
                        opacity: 0.09 * beamStrength
                    )

                    spotlight(
                        center: UnitPoint(x: x1, y: y1),
                        startRadius: 30,
                        endRadius: 340,
                        opacity: 0.09 * glowStrength,
                        blurRadius: 12
                    )

                    spotlight(
                        center: UnitPoint(x: x2, y: y2),
                        startRadius: 42,
                        endRadius: 390,
                        opacity: 0.07 * glowStrength,
                        blurRadius: 16
                    )

                    LinearGradient(
                        colors: [Color.black.opacity(style == .hero ? 0.44 : 0.62), Color.black.opacity(0.14), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()

                    LinearGradient(
                        colors: [Color.black.opacity(0.0), Color.black.opacity(0.58)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            }
        }
        .opacity(isAnimated ? 1 : 0)
        .animation(.easeOut(duration: 0.8), value: isAnimated)
    }

    private func spotlightBeam(
        size: CGSize,
        angle: Double,
        xOffset: CGFloat,
        opacity: Double
    ) -> some View {
        OnboardingBeamShape()
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

private struct OnboardingBeamShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct OnboardingHeader: View {
    let title: String
    let subtitle: String?
    var titleSize: CGFloat = OnboardingTheme.headlineSize
    var maxWidth: CGFloat = 340
    var alignment: TextAlignment = .center

    init(
        title: String,
        subtitle: String? = nil,
        titleSize: CGFloat = OnboardingTheme.headlineSize,
        maxWidth: CGFloat = 340,
        alignment: TextAlignment = .center
    ) {
        self.title = title
        self.subtitle = subtitle
        self.titleSize = titleSize
        self.maxWidth = maxWidth
        self.alignment = alignment
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(size: titleSize, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .kerning(-0.2)
                .multilineTextAlignment(alignment)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: OnboardingTheme.subheadlineSize, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))
                    .multilineTextAlignment(alignment)
                    .lineSpacing(1)
            }
        }
        .frame(maxWidth: maxWidth)
    }
}

struct OnboardingPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }

                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
            }
            .foregroundColor(isEnabled ? .black : .white.opacity(0.62))
            .frame(maxWidth: .infinity)
            .frame(height: OnboardingTheme.primaryButtonHeight)
            .background(isEnabled ? Color.upsideGreen : Color.upsideGreen.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: OnboardingTheme.buttonCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: OnboardingTheme.buttonCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(isEnabled ? 0.1 : 0.06), lineWidth: 1)
            )
            .shadow(color: isEnabled ? Color.upsideGreen.opacity(0.36) : .clear, radius: 20, x: 0, y: 12)
        }
        .disabled(!isEnabled)
    }
}

struct OnboardingSecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }

                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white.opacity(0.88))
            .frame(maxWidth: .infinity)
            .frame(height: OnboardingTheme.secondaryButtonHeight)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: OnboardingTheme.socialButtonCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: OnboardingTheme.socialButtonCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct OnboardingSocialButton: View {
    let title: String
    var systemIcon: String? = nil
    var assetIcon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let assetIcon {
                    Image(assetIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                } else if let systemIcon {
                    Image(systemName: systemIcon)
                        .font(.system(size: 18, weight: .semibold))
                }

                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: OnboardingTheme.secondaryButtonHeight)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: OnboardingTheme.socialButtonCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: OnboardingTheme.socialButtonCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 8)
        }
    }
}

struct OnboardingTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 18, weight: .medium, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: OnboardingTheme.fieldCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: OnboardingTheme.fieldCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
    }
}
