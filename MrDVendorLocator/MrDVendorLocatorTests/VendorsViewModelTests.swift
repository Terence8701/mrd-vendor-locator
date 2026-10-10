//
//  VendorsViewModelTests.swift
//  MrDVendorLocatorTests
//

import XCTest
@testable import MrDVendorLocator

@MainActor
final class VendorsViewModelTests: XCTestCase {

    private var repository: FakeVendorRepository!
    private var viewModel: VendorsViewModel!

    override func setUp() {
        super.setUp()
        repository = FakeVendorRepository()
        viewModel = VendorsViewModel(repository: repository)
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

private extension Vendor {
    static func stub(id: String, isFavorite: Bool = false) -> Vendor {
        Vendor(
            id: id,
            name: "Vendor \(id)",
            address: "1 Test St",
            coordinate: nil,
            isFavorite: isFavorite,
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}
