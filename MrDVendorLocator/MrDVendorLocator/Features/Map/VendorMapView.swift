//
//  VendorMapView.swift
//  MrDVendorLocator
//

import GoogleMaps
import SwiftUI

/// SwiftUI wrapper around `GMSMapView`. Holds no state of its own: vendors and the
/// current selection come in, marker taps go out through `onSelectVendor`.
struct VendorMapView: UIViewRepresentable {
    let vendors: [Vendor]
    let selection: VendorsViewModel.Selection?
    let onSelectVendor: (Vendor.ID) -> Void

    func makeCoordinator() -> MapCoordinator {
        MapCoordinator(onSelectVendor: onSelectVendor)
    }

    func makeUIView(context: Context) -> GMSMapView {
        // Start over South Africa; the coordinator fits the camera to the vendors once they load.
        let options = GMSMapViewOptions()
        options.camera = GMSCameraPosition(latitude: -29.0, longitude: 25.0, zoom: 4.5)
        let mapView = GMSMapView(options: options)
        mapView.delegate = context.coordinator
        mapView.settings.compassButton = true
        // Expose markers to VoiceOver; each reads its title (vendor name).
        mapView.accessibilityElementsHidden = false
        // No overrideUserInterfaceStyle: the Maps SDK follows light/dark mode automatically.
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        context.coordinator.onSelectVendor = onSelectVendor
        context.coordinator.update(mapView, vendors: vendors, selection: selection)
    }
}
