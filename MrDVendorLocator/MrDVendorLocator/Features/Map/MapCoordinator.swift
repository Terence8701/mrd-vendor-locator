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
    var onDeselect: () -> Void

    private var markers: [Vendor.ID: GMSMarker] = [:]
    /// The vendor each marker was last drawn from, to skip unchanged vendors.
    private var drawnVendors: [Vendor.ID: Vendor] = [:]
    private var handledSelectionID: UUID?
    private var handledFitRequest: UUID?
    private var hasFramedVendors = false

    init(onSelectVendor: @escaping (Vendor.ID) -> Void, onDeselect: @escaping () -> Void) {
        self.onSelectVendor = onSelectVendor
        self.onDeselect = onDeselect
    }

    func update(
        _ mapView: GMSMapView,
        vendors: [Vendor],
        selection: VendorsViewModel.Selection?,
        fitRequest: UUID?
    ) {
        syncMarkers(on: mapView, with: vendors)
        highlight(selection?.vendorID)
        updateCamera(of: mapView, selection: selection, fitRequest: fitRequest)
    }

    // MARK: - GMSMapViewDelegate

    func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
        guard let vendorID = marker.userData as? Vendor.ID else { return false }
        onSelectVendor(vendorID)
        // Handled: the selection change animates the camera, and the SwiftUI card shows
        // the details instead of Google's info window.
        return true
    }

    func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
        onDeselect()
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
            // The title is read by default; add the favorite state.
            marker.accessibilityLabel = vendor.isFavorite ? "\(vendor.name), favorite" : vendor.name
            marker.userData = vendor.id
            marker.map = mapView
            markers[vendor.id] = marker
            drawnVendors[vendor.id] = vendor
        }
    }

    /// Draws the selected vendor's marker above the others.
    private func highlight(_ vendorID: Vendor.ID?) {
        for (id, marker) in markers {
            marker.zIndex = id == vendorID ? 1 : 0
        }
    }

    private func updateCamera(
        of mapView: GMSMapView,
        selection: VendorsViewModel.Selection?,
        fitRequest: UUID?
    ) {
        // A new selection wins. If its vendor has no marker yet (still geocoding), it is
        // handled on a later update, once the marker exists.
        if let selection, selection.id != handledSelectionID, let marker = markers[selection.vendorID] {
            handledSelectionID = selection.id
            hasFramedVendors = true
            mapView.animate(with: GMSCameraUpdate.setTarget(marker.position, zoom: 15))
            return
        }

        // Frame all vendors the first time there are markers, and whenever asked to.
        let isNewFitRequest = fitRequest != nil && fitRequest != handledFitRequest
        guard !markers.isEmpty, !hasFramedVendors || isNewFitRequest else { return }
        hasFramedVendors = true
        handledFitRequest = fitRequest
        let bounds = markers.values.reduce(GMSCoordinateBounds()) { $0.includingCoordinate($1.position) }
        // Deferred one run loop so the map has its final size before fitting.
        DispatchQueue.main.async {
            mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 48))
        }
    }
}
