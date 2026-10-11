//
//  InMemoryTokenStore.swift
//  MrDVendorLocator
//

import Foundation
import os

/// A non-persistent `TokenStore` for tests and previews. The app uses `KeychainTokenStore`.
nonisolated final class InMemoryTokenStore: TokenStore {
    private let token: OSAllocatedUnfairLock<String?>

    init(token: String? = nil) {
        self.token = OSAllocatedUnfairLock(initialState: token)
    }

    func read() -> String? {
        token.withLock { $0 }
    }

    func save(_ token: String) throws {
        self.token.withLock { $0 = token }
    }

    func clear() throws {
        token.withLock { $0 = nil }
    }
}
