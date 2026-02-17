import SwiftUI

struct ContentView: View {
    @State private var showSplash = true

    var body: some View {
        GeometryReader { geo in
            let safeAreaTop = geo.safeAreaInsets.top

            ZStack {
                OnboardingCoordinatorView(showSplash: showSplash, safeAreaTop: safeAreaTop)
                    .tint(.upsideGreen)
                    .accentColor(.upsideGreen)

                if showSplash {
                    SplashView(show: $showSplash, safeAreaTop: safeAreaTop)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
