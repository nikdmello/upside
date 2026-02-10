import SwiftUI

extension Color {
    static let upsideGreen = Color(red: 0.698, green: 0.957, blue: 0.329)
}

struct UpsideLogo: View {
    var height: CGFloat = 90

    var body: some View {
        Image("UpsideAppIcon")
            .resizable()
            .scaledToFit()
            .frame(height: height)
    }
}
