import SwiftUI

struct ContentView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            OnboardingCoordinatorView(showSplash: showSplash)
                .tint(.upsideGreen)
                .accentColor(.upsideGreen)

            if showSplash {
                SplashView(show: $showSplash)
            }
        }
    }
}

#Preview {
    ContentView()
}
