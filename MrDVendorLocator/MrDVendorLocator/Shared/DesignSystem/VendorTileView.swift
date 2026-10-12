//
//  VendorTileView.swift
//  MrDVendorLocator
//

import SwiftUI

/// A coloured tile with the vendor's initials. The API has no images, so this gives
/// each vendor a recognisable mark without inventing photos.
struct VendorTileView: View {
    let vendor: Vendor
    var size: CGFloat = 56

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            .fill(color.gradient)
            .frame(width: size, height: size)
            .overlay {
                Text(initials)
                    .font(.system(size: size * 0.36, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }

    /// First letter of the first two words, e.g. "Sea Point Sushi Bar" → "SP".
    private var initials: String {
        vendor.name
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .prefix(2)
            .compactMap(\.first)
            .map { String($0).uppercased() }
            .joined()
    }

    /// Picked from the ID so a vendor keeps its colour across launches
    /// (`hashValue` is randomised per launch, so it isn't used here).
    private var color: Color {
        let palette: [Color] = [.orange, .red, .pink, .purple, .indigo, .blue, .teal, .green, .brown]
        let seed = vendor.id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[seed % palette.count]
    }
}
