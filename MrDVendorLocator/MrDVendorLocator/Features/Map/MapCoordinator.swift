//
//  MapCoordinator.swift
//  MrDVendorLocator
//

import GoogleMaps
import UIKit

/// Owns the markers for `VendorMapView` and acts as the map's delegate.
///
/// SwiftUI calls `update` often, so markers are diffed by vendor ID instead of being
/// recreated: new vendors get a marker, changed vendors are updated in place, and
/// vendors that disappeared are removed.
final class MapCoordinator: NSObject, GMSMapViewDelegate {
    var onSelectVendor: (Vendor.ID) -> Void

    private var markers: [Vendor.ID: GMSMarker] = [:]
    /// The vendor each marker was last drawn from, to skip unchanged vendors.
    private var drawnVendors: [Vendor.ID: Vendor] = [:]
    private var handledSelectionID: UUID?
    private var hasFramedVendors = false

    init(onSelectVendor: @escaping (Vendor.ID) -> Void) {
        self.onSelectVendor = onSelectVendor
    }

    func update(_ mapView: GMSMapView, vendors: [Vendor], selection: VendorsViewModel.Selection?) {
        syncMarkers(on: mapView, with: vendors)
        updateCamera(of: mapView, selection: selection)
    }

    // MARK: - GMSMapViewDelegate

    func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
        guard let vendorID = marker.userData as? Vendor.ID else { return false }
        onSelectVendor(vendorID)
        // Handled: the selection change animates the camera and opens the info window.
        return true
    }

    // MARK: - Private

    private func syncMarkers(on mapView: GMSMapView, with vendors: [Vendor]) {
        let located = vendors.filter { $0.coordinate != nil }
        let locatedIDs = Set(located.map(\.id))

        for (vendorID, marker) in markers where !locatedIDs.contains(vendorID) {
            marker.map = nil
            markers[vendorID] = nil
            drawnVendors[vendorID] = nil
        }

        for vendor in located where drawnVendors[vendor.id] != vendor {
            guard let coordinate = vendor.coordinate else { continue }
            let marker = markers[vendor.id] ?? GMSMarker()
            marker.position = CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
            marker.title = vendor.name
            marker.snippet = vendor.address
            marker.icon = GMSMarker.markerImage(with: vendor.isFavorite ? .systemRed : .systemOrange)
            marker.userData = vendor.id
            marker.map = mapView
            markers[vendor.id] = marker
            drawnVendors[vendor.id] = vendor
        }
    }

    private func updateCamera(of mapView: GMSMapView, selection: VendorsViewModel.Selection?) {
        // A new selection wins. If its vendor has no marker yet (still geocoding), it is
        // handled on a later update, once the marker exists.
        if let selection, selection.id != handledSelectionID, let marker = markers[selection.vendorID] {
            handledSelectionID = selection.id
            hasFramedVendors = true
            mapView.animate(with: GMSCameraUpdate.setTarget(marker.position, zoom: 15))
            mapView.selectedMarker = marker
            return
        }

        // Otherwise frame all vendors once, the first time there are markers.
        guard !hasFramedVendors, !markers.isEmpty else { return }
        hasFramedVendors = true
        let bounds = markers.values.reduce(GMSCoordinateBounds()) { $0.includingCoordinate($1.position) }
        // Deferred one run loop so the map has its final size before fitting.
        DispatchQueue.main.async {
            mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 48))
        }
    }
}
