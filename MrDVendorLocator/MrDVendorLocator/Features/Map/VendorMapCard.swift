//
//  VendorMapCard.swift
//  MrDVendorLocator
//

import SwiftUI

/// The selected vendor, shown over the map. Tapping it opens the vendor in the list.
struct VendorMapCard: View {
    let vendor: Vendor
    let onShowInList: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onShowInList) {
                HStack(spacing: 12) {
                    VendorTileView(vendor: vendor, size: 48)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(vendor.name)
                                .font(.headline)
                            if vendor.isFavorite {
                                Image(systemName: "heart.fill")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .accessibilityLabel("Favorite")
                            }
                        }
                        Text(vendor.address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows this vendor in the list")

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(.fill.tertiary, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
    }
}
