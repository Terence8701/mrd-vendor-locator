//
//  SettingsViewModelTests.swift
//  MrDVendorLocatorTests
//

import XCTest
@testable import MrDVendorLocator

@MainActor
final class SettingsViewModelTests: XCTestCase {

    private var tokenStore: InMemoryTokenStore!
    private var tokenChanges = 0

    private func makeViewModel(savedToken: String? = nil) -> SettingsViewModel {
        tokenStore = InMemoryTokenStore(token: savedToken)
        tokenChanges = 0
        return SettingsViewModel(tokenStore: tokenStore) { [weak self] in
            self?.tokenChanges += 1
        }
    }

    func testStartsWithSavedTokenHidden() {
        let viewModel = makeViewModel(savedToken: "abc")

        XCTAssertEqual(viewModel.draftToken, "abc")
        XCTAssertFalse(viewModel.isTokenRevealed)
        XCTAssertTrue(viewModel.hasSavedToken)
    }

    func testSaveTrimsAndPersistsAndNotifies() async {
        let viewModel = makeViewModel()
        viewModel.draftToken = "  new-token \n"

        await viewModel.save()

        XCTAssertEqual(tokenStore.read(), "new-token")
        XCTAssertEqual(viewModel.savedToken, "new-token")
        XCTAssertEqual(tokenChanges, 1)
    }

    func testCannotSaveBlankOrUnchangedToken() {
        let viewModel = makeViewModel(savedToken: "abc")

        viewModel.draftToken = "   "
        XCTAssertFalse(viewModel.canSave)

        viewModel.draftToken = "abc"
        XCTAssertFalse(viewModel.canSave)

        viewModel.draftToken = "abcd"
        XCTAssertTrue(viewModel.canSave)
    }

    func testClearRemovesTokenAndNotifies() async {
        let viewModel = makeViewModel(savedToken: "abc")

        await viewModel.clear()

        XCTAssertNil(tokenStore.read())
        XCTAssertFalse(viewModel.hasSavedToken)
        XCTAssertEqual(viewModel.draftToken, "")
        XCTAssertEqual(tokenChanges, 1)
    }
}
