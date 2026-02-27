import SwiftUI

private enum AppTestingConfig {
    #if DEBUG
    static let bypassOnboardingToBrandHome: Bool = {
        let rawValue = ProcessInfo.processInfo.environment["UPSIDE_BYPASS_ONBOARDING"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return rawValue == "1" || rawValue == "true" || rawValue == "yes"
    }()
    #else
    static let bypassOnboardingToBrandHome = false
    #endif
}

struct ContentView: View {
    @State private var showSplash = !AppTestingConfig.bypassOnboardingToBrandHome

    var body: some View {
        GeometryReader { geo in
            let safeAreaTop = geo.safeAreaInsets.top

            ZStack {
                if AppTestingConfig.bypassOnboardingToBrandHome {
                    HomeTabShellView(userRole: .brand)
                        .tint(.upsideGreen)
                        .accentColor(.upsideGreen)
                } else {
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
}

#Preview {
    ContentView()
}
