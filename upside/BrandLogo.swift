import SwiftUI

enum BrandLogo {
    static let height: CGFloat = 90
    static let scale: CGFloat = 1.3
    static let topPadding: CGFloat = 12

    static func topY(safeAreaTop: CGFloat) -> CGFloat {
        safeAreaTop + topPadding + (height * scale / 2)
    }
}
