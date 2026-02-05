import SwiftUI

struct SplashView: View {
    @Binding var show: Bool
    @State private var animateLogo = false

    var body: some View {
        GeometryReader { geo in
            let centerY = geo.size.height / 2
            let topY = BrandLogo.topY(safeAreaTop: geo.safeAreaInsets.top)

            ZStack {
                Color.black
                    .ignoresSafeArea()

                UpsideLogo()
                    .frame(height: BrandLogo.height)
                    .scaleEffect(BrandLogo.scale)
                    .position(x: geo.size.width / 2, y: animateLogo ? topY : centerY)
                    .animation(.easeInOut(duration: 0.7), value: animateLogo)
            }
            .onAppear {
                animateLogo = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                    show = false
                }
            }
        }
    }
}

#Preview {
    SplashView(show: .constant(true))
}
