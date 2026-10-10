//
//  AppDependencies.swift
//  MrDVendorLocator
//

import Foundation

/// The composition root: the only place concrete services are created.
/// Everything else receives its dependencies through `init`, typed as protocols.
@MainActor
final class AppDependencies {
    let tokenStore: TokenStore
    let vendorsViewModel: VendorsViewModel

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

        self.tokenStore = tokenStore
        self.vendorsViewModel = VendorsViewModel(repository: repository)
    }
}
