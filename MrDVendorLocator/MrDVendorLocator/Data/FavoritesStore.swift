//
//  FavoritesStore.swift
//  MrDVendorLocator
//

import Foundation

/// Remembers favorites the user changed locally. These override the server's
/// `isFavorite` until a real "favorite" endpoint exists.
nonisolated protocol FavoritesStore: Sendable {
    /// Vendor ID → favorite state, for vendors the user has toggled.
    func favoriteOverrides() -> [Vendor.ID: Bool]
    func setFavorite(_ isFavorite: Bool, for vendorID: Vendor.ID)
}

nonisolated final class UserDefaultsFavoritesStore: FavoritesStore, @unchecked Sendable {
    // @unchecked: UserDefaults is documented as thread-safe.
    private let defaults: UserDefaults
    private let key = "favoriteOverrides"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func favoriteOverrides() -> [Vendor.ID: Bool] {
        defaults.dictionary(forKey: key) as? [Vendor.ID: Bool] ?? [:]
    }

    func setFavorite(_ isFavorite: Bool, for vendorID: Vendor.ID) {
        var overrides = favoriteOverrides()
        overrides[vendorID] = isFavorite
        defaults.set(overrides, forKey: key)
    }
}
