//
//  VendorRowView.swift
//  MrDVendorLocator
//

import SwiftUI

struct VendorRowView: View {
    let vendor: Vendor
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Two separate buttons: the row selects, the heart toggles. Non-default
            // button styles stop List from turning the whole row into one tap target.
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    VendorTileView(vendor: vendor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(vendor.name)
                            .font(.headline)
                        Text(vendor.address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Updated \(vendor.updatedAt, format: .relative(presentation: .named))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows this vendor on the map")

            Button(action: onToggleFavorite) {
                Image(systemName: vendor.isFavorite ? "heart.fill" : "heart")
                    .font(.title3)
                    .foregroundStyle(vendor.isFavorite ? Color.red : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(vendor.isFavorite ? "Remove \(vendor.name) from favorites" : "Add \(vendor.name) to favorites")
            .sensoryFeedback(.selection, trigger: vendor.isFavorite)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        VendorRowView(
            vendor: Vendor(
                id: "ven-001",
                name: "Mr D Pizza — Cape Town CBD",
                address: "12 Loop St, Cape Town, 8000",
                coordinate: Coordinate(latitude: -33.918861, longitude: 18.4233),
                isFavorite: true,
                updatedAt: .now.addingTimeInterval(-3_600)
            ),
            onSelect: {},
            onToggleFavorite: {}
        )
    }
}
