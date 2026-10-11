//
//  GooglePlacesGeocoder.swift
//  MrDVendorLocator
//

import CoreLocation
import Foundation
import GooglePlacesSwift

/// Geocodes with Places API (New) Text Search, asking only for the coordinate field
/// to keep each request in the cheapest billing tier that includes it.
nonisolated final class GooglePlacesGeocoder: Geocoding {
    private let client: PlacesClient

    init(client: PlacesClient) {
        self.client = client
    }

    func coordinate(for address: String) async throws -> Coordinate {
        // Bias results to South Africa, where all vendors are.
        guard let southAfrica = RectangularCoordinateRegion(
            northEast: CLLocationCoordinate2D(latitude: -22.1, longitude: 32.9),
            southWest: CLLocationCoordinate2D(latitude: -34.9, longitude: 16.4)
        ) else { throw GeocodingError.invalidRequest }

        let request = SearchByTextRequest(
            textQuery: address,
            placeProperties: [.coordinate],
            locationBias: southAfrica,
            maxResultCount: 1,
            isOpenNow: false, // The SDK defaults to true, which would skip closed vendors.
            rankPreference: .relevance,
            regionCode: "ZA"
        )

        switch await client.responseForSearchByText(with: request) {
        case .success(let response):
            guard let location = response.places?.first?.location else { throw GeocodingError.notFound }
            return Coordinate(latitude: location.latitude, longitude: location.longitude)
        case .failure(let error):
            throw GeocodingError.service(error.localizedDescription)
        }
    }
}
