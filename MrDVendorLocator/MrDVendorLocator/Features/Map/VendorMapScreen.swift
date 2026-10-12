//
//  VendorMapScreen.swift
//  MrDVendorLocator
//

import GoogleMaps
import SwiftUI

/// The Map tab: the Google map with map controls, a card for the selected vendor and a
/// status overlay, or a clear message when no API key is configured.
struct VendorMapScreen: View {
    @Environment(VendorsViewModel.self) private var viewModel
    let isMapAvailable: Bool
    /// Called from the vendor card; the root view switches to the list.
    let onShowInList: (Vendor.ID) -> Void

    @State private var fitRequest: UUID?
    @State private var showsSatellite = false

    var body: some View {
        Group {
            if isMapAvailable {
                map
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

    private var map: some View {
        VendorMapView(
            vendors: viewModel.vendors,
            selection: viewModel.selection,
            fitRequest: fitRequest,
            mapType: showsSatellite ? .hybrid : .normal,
            onSelectVendor: { viewModel.select($0) },
            onDeselect: { viewModel.clearSelection() }
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
        .overlay(alignment: .topTrailing) {
            VStack(spacing: 12) {
                MapControlButton(
                    systemImage: showsSatellite ? "map" : "square.2.layers.3d",
                    label: showsSatellite ? "Show standard map" : "Show satellite map"
                ) {
                    showsSatellite.toggle()
                }
                MapControlButton(systemImage: "scope", label: "Show all vendors") {
                    viewModel.clearSelection()
                    fitRequest = UUID()
                }
            }
            .padding(12)
        }
        .overlay(alignment: .bottom) {
            if let vendor = viewModel.selectedVendor {
                VendorMapCard(
                    vendor: vendor,
                    onShowInList: { onShowInList(vendor.id) },
                    onClose: { viewModel.clearSelection() }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.default, value: viewModel.isResolvingLocations)
        .animation(.snappy, value: viewModel.selectedVendorID)
    }
}

/// A round floating button over the map.
private struct MapControlButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
                .frame(width: 44, height: 44)
                .background(.regularMaterial, in: Circle())
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
