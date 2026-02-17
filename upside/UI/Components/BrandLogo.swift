import SwiftUI

enum BrandLogo {
    static let width: CGFloat = 264
    static let height: CGFloat = 108
    static let scale: CGFloat = 1.0
    static let topPadding: CGFloat = 18
    static let launchStartYOffset: CGFloat = 50

    static func topInset(safeAreaTop: CGFloat) -> CGFloat {
        safeAreaTop + topPadding
    }

    static func topY(safeAreaTop: CGFloat) -> CGFloat {
        topInset(safeAreaTop: safeAreaTop) + (height * scale / 2)
    }
}

struct BrandLogoView: View {
    var body: some View {
        UpsideLogo(width: BrandLogo.width, height: BrandLogo.height)
            .frame(width: BrandLogo.width, height: BrandLogo.height)
    }
}
