//
//  SettingsViewModel.swift
//  MrDVendorLocator
//

import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    /// What's in the text field. Starts as the saved token.
    var draftToken: String
    var isTokenRevealed = false
    private(set) var savedToken: String?
    private(set) var errorMessage: String?

    @ObservationIgnored private let tokenStore: TokenStore
    /// Called after the token is saved or cleared, so vendors reload with the new token.
    @ObservationIgnored private let onTokenChanged: @MainActor () async -> Void

    init(tokenStore: TokenStore, onTokenChanged: @escaping @MainActor () async -> Void) {
        self.tokenStore = tokenStore
        self.onTokenChanged = onTokenChanged
        let saved = tokenStore.read()
        self.savedToken = saved
        self.draftToken = saved ?? ""
    }

    var hasSavedToken: Bool {
        savedToken != nil
    }

    var canSave: Bool {
        let trimmed = trimmedDraft
        return !trimmed.isEmpty && trimmed != savedToken
    }

    func save() async {
        guard canSave else { return }
        do {
            try tokenStore.save(trimmedDraft)
            savedToken = trimmedDraft
            draftToken = trimmedDraft
            errorMessage = nil
            isTokenRevealed = false
            await onTokenChanged()
        } catch {
            errorMessage = "Couldn't save the token to the Keychain. Please try again."
        }
    }

    func clear() async {
        do {
            try tokenStore.clear()
            savedToken = nil
            draftToken = ""
            errorMessage = nil
            isTokenRevealed = false
            await onTokenChanged()
        } catch {
            errorMessage = "Couldn't remove the token from the Keychain. Please try again."
        }
    }

    private var trimmedDraft: String {
        draftToken.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
