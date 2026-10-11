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
    let tokenStore: TokenStore
    let vendorsViewModel: VendorsViewModel
    /// False when no Google API key is configured; the Map tab then explains why.
    let isMapAvailable: Bool

    init() {
        // Temporary: a demo token in memory so the stub API accepts requests.
        // Replaced by KeychainTokenStore once the Settings screen exists.
        let tokenStore = InMemoryTokenStore(token: "demo-session-token")

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

        self.tokenStore = tokenStore
        self.vendorsViewModel = VendorsViewModel(
            repository: repository,
            geocoder: CachingGeocoder(wrapping: geocoder)
        )
    }
}
