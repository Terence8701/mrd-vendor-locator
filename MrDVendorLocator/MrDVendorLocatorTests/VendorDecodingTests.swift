//
//  VendorDecodingTests.swift
//  MrDVendorLocatorTests
//

import XCTest
@testable import MrDVendorLocator

final class VendorDecodingTests: XCTestCase {

    private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        try JSONDecoder.api().decode(type, from: Data(json.utf8))
    }

    func testDecodesFullVendor() throws {
        let json = """
        {
          "id": "ven-001",
          "name": "Mr D Pizza — Cape Town CBD",
          "address": "12 Loop St, Cape Town, 8000",
          "coordinate": { "lat": -33.918861, "lng": 18.4233 },
          "isFavorite": true,
          "updatedAt": "2026-09-28T12:00:00Z"
        }
        """

        let vendor = try decode(Vendor.self, from: json)

        XCTAssertEqual(vendor.id, "ven-001")
        XCTAssertEqual(vendor.name, "Mr D Pizza — Cape Town CBD")
        XCTAssertEqual(vendor.address, "12 Loop St, Cape Town, 8000")
        XCTAssertEqual(vendor.coordinate, Coordinate(latitude: -33.918861, longitude: 18.4233))
        XCTAssertTrue(vendor.isFavorite)
    }

    func testDecodesVendorWithoutCoordinate() throws {
        let json = """
        {
          "id": "ven-004",
          "name": "Stellenbosch Bakehouse",
          "address": "100 Dorp St, Stellenbosch, 7600",
          "isFavorite": false,
          "updatedAt": "2026-10-02T09:00:00Z"
        }
        """

        let vendor = try decode(Vendor.self, from: json)

        XCTAssertNil(vendor.coordinate)
        XCTAssertEqual(vendor.address, "100 Dorp St, Stellenbosch, 7600")
    }

    func testDecodesISO8601Date() throws {
        let json = """
        {
          "id": "ven-001", "name": "A", "address": "B",
          "isFavorite": false, "updatedAt": "2026-09-28T12:00:00Z"
        }
        """

        let vendor = try decode(Vendor.self, from: json)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let expected = calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 12))
        XCTAssertEqual(vendor.updatedAt, expected)
    }

    func testMalformedJSONThrows() {
        let json = #"{ "id": "ven-001", "name": "Missing the rest" "#

        XCTAssertThrowsError(try decode(Vendor.self, from: json))
    }

    func testMissingRequiredFieldThrows() {
        // `updatedAt` is required.
        let json = #"{ "id": "ven-001", "name": "A", "address": "B", "isFavorite": false }"#

        XCTAssertThrowsError(try decode(Vendor.self, from: json)) { error in
            guard case DecodingError.keyNotFound(let key, _) = error else {
                return XCTFail("Expected keyNotFound, got \(error)")
            }
            XCTAssertEqual(key.stringValue, "updatedAt")
        }
    }

    func testBundledVendorsFileDecodes() throws {
        let url = try XCTUnwrap(Bundle(for: StubURLProtocol.self).url(forResource: "vendors", withExtension: "json"))

        let response = try JSONDecoder.api().decode(VendorsResponse.self, from: Data(contentsOf: url))

        XCTAssertEqual(response.vendors.count, 10)
        XCTAssertEqual(response.vendors.filter { $0.coordinate == nil }.count, 3)
    }
}
