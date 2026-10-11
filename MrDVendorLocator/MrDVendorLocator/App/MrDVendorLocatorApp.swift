//
//  MrDVendorLocatorApp.swift
//  MrDVendorLocator
//
//  Created by Terence Baloyi on 2026/10/10.
//

import SwiftUI

@main
struct MrDVendorLocatorApp: App {
    @State private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootTabView(isMapAvailable: dependencies.isMapAvailable)
                .environment(dependencies.vendorsViewModel)
                .environment(dependencies.settingsViewModel)
        }
    }
}
