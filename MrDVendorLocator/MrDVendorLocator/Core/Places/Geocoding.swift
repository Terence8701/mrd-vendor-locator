//
//  Geocoding.swift
//  MrDVendorLocator
//

import Foundation

/// Resolves a street address to a coordinate. The explicit integration boundary with
/// Google Places: the app depends on this protocol, never on the Places SDK directly.
nonisolated protocol Geocoding: Sendable {
    func coordinate(for address: String) async throws -> Coordinate
}

nonisolated enum GeocodingError: Error, Equatable, Sendable {
    case notFound
    case invalidRequest
    case service(String)
}
