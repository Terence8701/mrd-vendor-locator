//
//  RootTabView.swift
//  MrDVendorLocator
//

import SwiftUI

struct RootTabView: View {
    enum AppTab: Hashable {
        case vendors, map, settings
    }

    let isMapAvailable: Bool

    @Environment(VendorsViewModel.self) private var vendorsViewModel
    @State private var selectedTab: AppTab = .vendors

    var body: some View {
        TabView(selection: $selectedTab) {
            VendorListView(
                onSelect: { vendor in
                    vendorsViewModel.select(vendor.id)
                    selectedTab = .map
                },
                onOpenSettings: { selectedTab = .settings }
            )
            .tabItem { Label("Vendors", systemImage: "list.bullet") }
            .tag(AppTab.vendors)

            VendorMapScreen(isMapAvailable: isMapAvailable)
                .tabItem { Label("Map", systemImage: "map") }
                .tag(AppTab.map)

            // Replaced by SettingsView in Phase 4.
            ContentUnavailableView("Settings", systemImage: "gearshape", description: Text("Coming soon."))
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
    }
}
