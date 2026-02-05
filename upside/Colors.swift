import SwiftUI

extension Color {
    static let upsideGreen = Color(red: 0.165, green: 0.667, blue: 0.455)
}

struct UpsideLogo: View {
    var body: some View {
        Image("UpsideWordmark")
            .resizable()
            .scaledToFit()
            .frame(height: 40)
    }
}
