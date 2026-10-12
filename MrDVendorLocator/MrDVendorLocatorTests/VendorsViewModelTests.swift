//
//  VendorsViewModelTests.swift
//  MrDVendorLocatorTests
//

import XCTest
@testable import MrDVendorLocator

@MainActor
final class VendorsViewModelTests: XCTestCase {

    private var repository: FakeVendorRepository!
    private var geocoder: FakeGeocoder!
    private var viewModel: VendorsViewModel!

    override func setUp() {
        super.setUp()
        repository = FakeVendorRepository()
        geocoder = FakeGeocoder()
        viewModel = VendorsViewModel(repository: repository, geocoder: geocoder)
    }

    func testLoadSuccessShowsVendors() async {
        repository.fetchResult = .success([.stub(id: "a"), .stub(id: "b")])

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.vendors.map(\.id), ["a", "b"])
    }

    func testLoadWithNoVendorsIsEmpty() async {
        repository.fetchResult = .success([])

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.state, .empty)
    }

    func testUnauthorizedFailureSendsUserToSettings() async {
        repository.fetchResult = .failure(APIError.unauthorized)

        await viewModel.loadIfNeeded()

        guard case .failed(let error) = viewModel.state else {
            return XCTFail("Expected .failed, got \(viewModel.state)")
        }
        XCTAssertEqual(error.action, .openSettings)
    }

    func testFailedRefreshKeepsExistingVendors() async {
        repository.fetchResult = .success([.stub(id: "a")])
        await viewModel.loadIfNeeded()

        repository.fetchResult = .failure(APIError.offline)
        await viewModel.reload()

        XCTAssertEqual(viewModel.vendors.map(\.id), ["a"])
        XCTAssertNotNil(viewModel.transientError)
    }

    func testUnauthorizedRefreshClearsExistingVendors() async {
        repository.fetchResult = .success([.stub(id: "a")])
        await viewModel.loadIfNeeded()

        repository.fetchResult = .failure(APIError.unauthorized)
        await viewModel.reload()

        XCTAssertTrue(viewModel.vendors.isEmpty, "Vendors must not stay visible once the session is gone")
        guard case .failed(let error) = viewModel.state else {
            return XCTFail("Expected .failed, got \(viewModel.state)")
        }
        XCTAssertEqual(error.action, .openSettings)
    }

    func testToggleFavoriteUpdatesAndPersists() async {
        repository.fetchResult = .success([.stub(id: "a", isFavorite: false)])
        await viewModel.loadIfNeeded()

        await viewModel.toggleFavorite("a")

        XCTAssertEqual(viewModel.vendors.first?.isFavorite, true)
        XCTAssertEqual(repository.savedFavorites["a"], true)
    }

    func testToggleFavoriteRollsBackWhenSaveFails() async {
        repository.fetchResult = .success([.stub(id: "a", isFavorite: false)])
        repository.setFavoriteError = APIError.server(statusCode: 500)
        await viewModel.loadIfNeeded()

        await viewModel.toggleFavorite("a")

        XCTAssertEqual(viewModel.vendors.first?.isFavorite, false)
        XCTAssertEqual(viewModel.transientError, .favoriteUpdateFailed)
    }

    func testSelectSetsSelectedVendor() {
        viewModel.select("b")

        XCTAssertEqual(viewModel.selectedVendorID, "b")
    }

    func testSelectingSameVendorAgainCreatesNewFocusRequest() {
        viewModel.select("b")
        let first = viewModel.selection

        viewModel.select("b")

        XCTAssertNotEqual(viewModel.selection, first, "Re-selecting must re-centre the map")
    }

    func testGeocodesOnlyVendorsMissingCoordinates() async {
        let located = Vendor.stub(id: "a", coordinate: Coordinate(latitude: 1, longitude: 1))
        let unlocated = Vendor.stub(id: "b", address: "2 Missing Rd")
        repository.fetchResult = .success([located, unlocated])
        geocoder.result = .success(Coordinate(latitude: -33.9, longitude: 18.4))

        await viewModel.loadIfNeeded()
        await viewModel.locationTask?.value

        XCTAssertEqual(geocoder.requestedAddresses, ["2 Missing Rd"])
        XCTAssertEqual(viewModel.vendors.last?.coordinate, Coordinate(latitude: -33.9, longitude: 18.4))
        XCTAssertFalse(viewModel.isResolvingLocations)
    }

    func testFailedGeocodeKeepsVendorWithoutCoordinate() async {
        repository.fetchResult = .success([.stub(id: "b")])
        geocoder.result = .failure(GeocodingError.notFound)

        await viewModel.loadIfNeeded()
        await viewModel.locationTask?.value

        XCTAssertEqual(viewModel.vendors.map(\.id), ["b"], "The list must not fail because of geocoding")
        XCTAssertNil(viewModel.vendors.first?.coordinate)
        XCTAssertFalse(viewModel.isResolvingLocations)
    }

    // MARK: - Search and filter

    func testFavoritesFilterShowsOnlyFavorites() async {
        repository.fetchResult = .success([.stub(id: "a", isFavorite: true), .stub(id: "b")])
        await viewModel.loadIfNeeded()

        viewModel.filter = .favorites

        XCTAssertEqual(viewModel.visibleVendors.map(\.id), ["a"])
    }

    func testSearchMatchesNameOrAddressIgnoringCaseAndAccents() async {
        repository.fetchResult = .success([
            .stub(id: "a", name: "Sea Point Sushi Bar"),
            .stub(id: "b", name: "Harbour Grill", address: "19 Dock Rd, Cape Town"),
            .stub(id: "c", name: "Café Rosebank"),
        ])
        await viewModel.loadIfNeeded()

        viewModel.searchText = "SUSHI"
        XCTAssertEqual(viewModel.visibleVendors.map(\.id), ["a"])

        viewModel.searchText = "dock rd"
        XCTAssertEqual(viewModel.visibleVendors.map(\.id), ["b"])

        viewModel.searchText = "cafe"
        XCTAssertEqual(viewModel.visibleVendors.map(\.id), ["c"])
    }

    func testSearchAndFilterCombine() async {
        repository.fetchResult = .success([
            .stub(id: "a", name: "Pizza One", isFavorite: true),
            .stub(id: "b", name: "Pizza Two"),
        ])
        await viewModel.loadIfNeeded()

        viewModel.filter = .favorites
        viewModel.searchText = "pizza"

        XCTAssertEqual(viewModel.visibleVendors.map(\.id), ["a"])
        XCTAssertTrue(viewModel.isFiltering)
    }

    func testRevealInListClearsFiltersThatHideTheVendor() async {
        repository.fetchResult = .success([.stub(id: "a", isFavorite: true), .stub(id: "b")])
        await viewModel.loadIfNeeded()
        viewModel.filter = .favorites
        viewModel.searchText = "Vendor a"

        viewModel.revealInList("b")

        XCTAssertEqual(viewModel.filter, .all)
        XCTAssertEqual(viewModel.searchText, "")
        XCTAssertEqual(viewModel.listFocus?.vendorID, "b")
    }

    func testRevealInListKeepsFiltersWhenVendorIsVisible() async {
        repository.fetchResult = .success([.stub(id: "a", isFavorite: true), .stub(id: "b")])
        await viewModel.loadIfNeeded()
        viewModel.filter = .favorites

        viewModel.revealInList("a")

        XCTAssertEqual(viewModel.filter, .favorites)
        XCTAssertEqual(viewModel.listFocus?.vendorID, "a")
    }

    func testClearSelectionRemovesSelectedVendor() async {
        repository.fetchResult = .success([.stub(id: "a")])
        await viewModel.loadIfNeeded()
        viewModel.select("a")
        XCTAssertEqual(viewModel.selectedVendor?.id, "a")

        viewModel.clearSelection()

        XCTAssertNil(viewModel.selectedVendor)
    }
}

// MARK: - Test doubles

private final class FakeVendorRepository: VendorRepository, @unchecked Sendable {
    var fetchResult: Result<[Vendor], Error> = .success([])
    var setFavoriteError: Error?
    private(set) var savedFavorites: [Vendor.ID: Bool] = [:]

    func fetchVendors() async throws -> [Vendor] {
        try fetchResult.get()
    }

    func setFavorite(_ isFavorite: Bool, for vendorID: Vendor.ID) async throws {
        if let setFavoriteError { throw setFavoriteError }
        savedFavorites[vendorID] = isFavorite
    }
}

private final class FakeGeocoder: Geocoding, @unchecked Sendable {
    var result: Result<Coordinate, Error> = .failure(GeocodingError.notFound)
    private(set) var requestedAddresses: [String] = []

    func coordinate(for address: String) async throws -> Coordinate {
        requestedAddresses.append(address)
        return try result.get()
    }
}

private extension Vendor {
    static func stub(
        id: String,
        name: String? = nil,
        address: String = "1 Test St",
        coordinate: Coordinate? = nil,
        isFavorite: Bool = false
    ) -> Vendor {
        Vendor(
            id: id,
            name: name ?? "Vendor \(id)",
            address: address,
            coordinate: coordinate,
            isFavorite: isFavorite,
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}
