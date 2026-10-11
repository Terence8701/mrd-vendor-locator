//
//  AppDependencies.swift
//  MrDVendorLocator
//

import Foundation
import GooglePlacesSwift

/// The composition root: the only place concrete services are created.
/// Everything else receives its dependencies through `init`, typed as protocols.
@MainActor
final class AppDependencies {
    let vendorsViewModel: VendorsViewModel
    let settingsViewModel: SettingsViewModel
    /// False when no Google API key is configured; the Map tab then explains why.
    let isMapAvailable: Bool

    init() {
        let tokenStore = KeychainTokenStore()

        let apiClient = URLSessionAPIClient(
            baseURL: StubURLProtocol.baseURL,
            session: .stubbed(),
            tokenStore: tokenStore
        )
        let repository = RemoteVendorRepository(
            apiClient: apiClient,
            favoritesStore: UserDefaultsFavoritesStore()
        )

        // With a key: real Google Maps and Places. Without one: no map tiles, and
        // geocoding falls back to an offline table so the app still runs.
        let geocoder: Geocoding
        if let apiKey = GoogleMapsPlatform.apiKey() {
            GoogleMapsPlatform.configure(apiKey: apiKey)
            geocoder = GooglePlacesGeocoder(client: PlacesClient.shared)
            isMapAvailable = true
        } else {
            geocoder = MockGeocoder.demo
            isMapAvailable = false
        }

        let vendorsViewModel = VendorsViewModel(
            repository: repository,
            geocoder: CachingGeocoder(wrapping: geocoder)
        )
        self.vendorsViewModel = vendorsViewModel
        // Saving or clearing the token reloads vendors, so the change shows immediately.
        self.settingsViewModel = SettingsViewModel(tokenStore: tokenStore) {
            await vendorsViewModel.reload()
        }
    }
}
