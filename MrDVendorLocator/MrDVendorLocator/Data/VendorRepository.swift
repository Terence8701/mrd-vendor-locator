//
//  VendorRepository.swift
//  MrDVendorLocator
//

import Foundation

/// The view models' only source of vendors. Hides where vendors and favorites come from.
nonisolated protocol VendorRepository: Sendable {
    func fetchVendors() async throws -> [Vendor]
    func setFavorite(_ isFavorite: Bool, for vendorID: Vendor.ID) async throws
}

/// Fetches vendors from the API and applies the user's local favorite changes on top.
nonisolated final class RemoteVendorRepository: VendorRepository {
    private let apiClient: APIClient
    private let favoritesStore: FavoritesStore

    init(apiClient: APIClient, favoritesStore: FavoritesStore) {
        self.apiClient = apiClient
        self.favoritesStore = favoritesStore
    }

    func fetchVendors() async throws -> [Vendor] {
        let response: VendorsResponse = try await apiClient.send(.vendors)
        let overrides = favoritesStore.favoriteOverrides()
        return response.vendors.map { vendor in
            var vendor = vendor
            if let isFavorite = overrides[vendor.id] {
                vendor.isFavorite = isFavorite
            }
            return vendor
        }
    }

    func setFavorite(_ isFavorite: Bool, for vendorID: Vendor.ID) async throws {
        // Async/throwing so a real endpoint can replace local storage without changing callers.
        favoritesStore.setFavorite(isFavorite, for: vendorID)
    }
}
