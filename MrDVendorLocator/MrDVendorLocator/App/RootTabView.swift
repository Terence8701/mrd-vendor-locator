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

            VendorMapScreen(
                isMapAvailable: isMapAvailable,
                onShowInList: { vendorID in
                    vendorsViewModel.revealInList(vendorID)
                    selectedTab = .vendors
                }
            )
                .tabItem { Label("Map", systemImage: "map") }
                .tag(AppTab.map)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
    }
}
