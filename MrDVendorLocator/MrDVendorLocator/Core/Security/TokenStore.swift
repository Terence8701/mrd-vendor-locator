//
//  TokenStore.swift
//  MrDVendorLocator
//

import Foundation

/// Persists the session token. The production implementation is Keychain-backed.
nonisolated protocol TokenStore: Sendable {
    func read() -> String?
    func save(_ token: String) throws
    func clear() throws
}
