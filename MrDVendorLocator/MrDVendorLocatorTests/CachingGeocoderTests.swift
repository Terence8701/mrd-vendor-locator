//
//  CachingGeocoderTests.swift
//  MrDVendorLocatorTests
//

import XCTest
@testable import MrDVendorLocator

final class CachingGeocoderTests: XCTestCase {

    func testRepeatedLookupUsesCache() async throws {
        let source = CountingGeocoder()
        let geocoder = CachingGeocoder(wrapping: source)

        let first = try await geocoder.coordinate(for: "12 Loop St, Cape Town")
        let second = try await geocoder.coordinate(for: "12 Loop St, Cape Town")

        XCTAssertEqual(first, second)
        let calls = await source.calls
        XCTAssertEqual(calls, 1)
    }

    func testCacheKeyIgnoresCaseAndSpacing() async throws {
        let source = CountingGeocoder()
        let geocoder = CachingGeocoder(wrapping: source)

        _ = try await geocoder.coordinate(for: "12 Loop St, Cape Town")
        _ = try await geocoder.coordinate(for: "12  loop st,   CAPE TOWN")

        let calls = await source.calls
        XCTAssertEqual(calls, 1)
    }

    func testConcurrentLookupsForSameAddressShareOneRequest() async throws {
        let source = CountingGeocoder(delay: .milliseconds(100))
        let geocoder = CachingGeocoder(wrapping: source)

        async let first = geocoder.coordinate(for: "100 Dorp St")
        async let second = geocoder.coordinate(for: "100 Dorp St")
        _ = try await (first, second)

        let calls = await source.calls
        XCTAssertEqual(calls, 1)
    }

    func testFailuresAreNotCached() async throws {
        let source = CountingGeocoder(failuresBeforeSuccess: 1)
        let geocoder = CachingGeocoder(wrapping: source)

        do {
            _ = try await geocoder.coordinate(for: "Lighthouse Rd")
            XCTFail("Expected the first lookup to fail")
        } catch {}
        _ = try await geocoder.coordinate(for: "Lighthouse Rd")

        let calls = await source.calls
        XCTAssertEqual(calls, 2)
    }
}

private actor CountingGeocoder: Geocoding {
    private(set) var calls = 0
    private let delay: Duration
    private var failuresRemaining: Int

    init(delay: Duration = .zero, failuresBeforeSuccess: Int = 0) {
        self.delay = delay
        self.failuresRemaining = failuresBeforeSuccess
    }

    func coordinate(for address: String) async throws -> Coordinate {
        calls += 1
        try await Task.sleep(for: delay)
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw GeocodingError.notFound
        }
        return Coordinate(latitude: -33.9, longitude: 18.4)
    }
}
