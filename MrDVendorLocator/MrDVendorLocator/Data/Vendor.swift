//
//  Vendor.swift
//  MrDVendorLocator
//

import Foundation

/// A vendor as returned by `GET /v1/vendors`.
///
/// `nonisolated` because the target defaults to MainActor isolation, and models
/// are decoded and passed around off the main actor.
nonisolated struct Vendor: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let address: String
    /// Optional: some vendors only have an address and are geocoded at runtime.
    var coordinate: Coordinate?
    var isFavorite: Bool
    let updatedAt: Date
}

nonisolated struct Coordinate: Codable, Sendable, Hashable {
    let latitude: Double
    let longitude: Double

    private enum CodingKeys: String, CodingKey {
        case latitude = "lat"
        case longitude = "lng"
    }
}

/// Top-level envelope of the vendors response: `{ "vendors": [...] }`.
nonisolated struct VendorsResponse: Codable, Sendable {
    let vendors: [Vendor]
}
