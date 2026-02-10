import SwiftUI

struct SplashView: View {
    @Binding var show: Bool
    @State private var logoAtTop = false

    var body: some View {
        GeometryReader { geo in
            let centerY = geo.size.height / 2
            let topY = BrandLogo.topY(safeAreaTop: geo.safeAreaInsets.top)

            ZStack {
                Color.black
                    .ignoresSafeArea()

                BrandLogoView()
                    .position(x: geo.size.width / 2, y: logoAtTop ? topY : centerY)
                    .animation(.easeInOut(duration: 0.7), value: logoAtTop)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { logoAtTop = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { show = false }
            }
        }
    }
}

#Preview {
    SplashView(show: .constant(true))
}
