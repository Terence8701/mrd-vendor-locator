//
//  MockGeocoder.swift
//  MrDVendorLocator
//

import Foundation

/// An offline `Geocoding` backed by a lookup table. Used when no Google API key is
/// configured, so the app still works for anyone cloning the repo.
nonisolated struct MockGeocoder: Geocoding {
    let coordinates: [String: Coordinate]

    func coordinate(for address: String) async throws -> Coordinate {
        guard let coordinate = coordinates[address] else { throw GeocodingError.notFound }
        return coordinate
    }
}

extension MockGeocoder {
    /// Approximate coordinates for the bundled vendors that ship without one.
    static let demo = MockGeocoder(coordinates: [
        "100 Dorp St, Stellenbosch, 7600": Coordinate(latitude: -33.9387, longitude: 18.8590),
        "338 Bronkhorst St, Brooklyn, Pretoria, 0181": Coordinate(latitude: -25.7705, longitude: 28.2370),
        "Lighthouse Rd, Umhlanga Rocks, Durban, 4320": Coordinate(latitude: -29.7243, longitude: 31.0893),
    ])
}
