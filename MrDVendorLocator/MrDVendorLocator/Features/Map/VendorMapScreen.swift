//
//  VendorMapScreen.swift
//  MrDVendorLocator
//

import SwiftUI

/// The Map tab: the Google map plus a status overlay, or a clear message when no
/// API key is configured.
struct VendorMapScreen: View {
    @Environment(VendorsViewModel.self) private var viewModel
    let isMapAvailable: Bool

    var body: some View {
        Group {
            if isMapAvailable {
                VendorMapView(
                    vendors: viewModel.vendors,
                    selection: viewModel.selection,
                    onSelectVendor: { viewModel.select($0) }
                )
                .overlay(alignment: .top) {
                    if viewModel.isResolvingLocations {
                        Label("Locating vendors…", systemImage: "location.magnifyingglass")
                            .font(.footnote)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.regularMaterial, in: Capsule())
                            .padding(.top, 8)
                            .transition(.opacity)
                    }
                }
                .animation(.default, value: viewModel.isResolvingLocations)
            } else {
                ContentUnavailableView(
                    "Map unavailable",
                    systemImage: "map",
                    description: Text("Add a Google Maps API key to Config/Secrets.xcconfig to show the map.")
                )
            }
        }
        // In case the map tab is opened before the list has loaded.
        .task { await viewModel.loadIfNeeded() }
    }
}
