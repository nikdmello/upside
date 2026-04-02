import SwiftUI

struct ContentView: View {
    @StateObject private var appSession = AppSessionStore.shared
    @State private var showSplash = !AppTestingConfiguration.bypassOnboarding

    var body: some View {
        GeometryReader { geo in
            let safeAreaTop = geo.safeAreaInsets.top

            ZStack {
                if AppTestingConfiguration.bypassOnboarding {
                    HomeTabShellView(
                        userRole: AppTestingConfiguration.bypassRole,
                        onSignOut: {
                            appSession.signOut()
                        }
                    )
                        .tint(.upsideGreen)
                        .accentColor(.upsideGreen)
                } else if appSession.isAuthenticated, let userRole = appSession.userRole {
                    HomeTabShellView(
                        userRole: userRole,
                        onSignOut: {
                            appSession.signOut()
                        }
                    )
                    .tint(.upsideGreen)
                    .accentColor(.upsideGreen)
                } else {
                    OnboardingCoordinatorView(
                        showSplash: showSplash,
                        safeAreaTop: safeAreaTop,
                        appSession: appSession
                    )
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
