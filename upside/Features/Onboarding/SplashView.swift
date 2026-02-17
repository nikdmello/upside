import SwiftUI

struct SplashView: View {
    @Binding var show: Bool
    let safeAreaTop: CGFloat
    @State private var logoProgress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let startY = (geo.size.height * 0.5) + BrandLogo.launchStartYOffset
            let topY = BrandLogo.topY(safeAreaTop: safeAreaTop)
            let currentY = startY + ((topY - startY) * logoProgress)

            ZStack {
                Color.black
                    .ignoresSafeArea()

                BrandLogoView()
                    .position(x: geo.size.width * 0.5, y: currentY)
                    .animation(
                        .timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.72),
                        value: logoProgress
                    )
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .ignoresSafeArea()
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                    logoProgress = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { show = false }
            }
        }
    }
}

#Preview {
    SplashView(show: .constant(true), safeAreaTop: 0)
}
