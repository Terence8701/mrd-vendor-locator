//
//  CachingGeocoder.swift
//  MrDVendorLocator
//

import Foundation

/// Wraps any `Geocoding` and remembers results by address, so refreshes don't repeat
/// paid lookups. Concurrent requests for the same address share one lookup.
/// Failures aren't cached, so a later attempt can succeed.
actor CachingGeocoder: Geocoding {
    private let wrapped: Geocoding
    private var cache: [String: Coordinate] = [:]
    private var inFlight: [String: Task<Coordinate, Error>] = [:]

    init(wrapping wrapped: Geocoding) {
        self.wrapped = wrapped
    }

    func coordinate(for address: String) async throws -> Coordinate {
        let key = Self.cacheKey(for: address)
        if let cached = cache[key] { return cached }
        if let pending = inFlight[key] { return try await pending.value }

        let wrapped = self.wrapped
        let task = Task { try await wrapped.coordinate(for: address) }
        inFlight[key] = task
        defer { inFlight[key] = nil }

        let coordinate = try await task.value
        cache[key] = coordinate
        return coordinate
    }

    /// "12 Loop St,  Cape Town" and "12 loop st, cape town" are the same lookup.
    private static func cacheKey(for address: String) -> String {
        address
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
