import SwiftUI

enum BrandLogo {
    static let height: CGFloat = 90
    static let scale: CGFloat = 1.0
    static let topPadding: CGFloat = 12

    static func topY(safeAreaTop: CGFloat) -> CGFloat {
        safeAreaTop + topPadding + (height * scale / 2)
    }
}

struct BrandLogoView: View {
    var body: some View {
        UpsideLogo(height: BrandLogo.height)
            .frame(height: BrandLogo.height)
    }
}
