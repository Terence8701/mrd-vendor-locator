//
//  KeychainTokenStoreTests.swift
//  MrDVendorLocatorTests
//

import XCTest
@testable import MrDVendorLocator

final class KeychainTokenStoreTests: XCTestCase {

    /// A unique service per test run, so tests never touch the app's real token.
    private var store: KeychainTokenStore!

    override func setUp() {
        super.setUp()
        store = KeychainTokenStore(service: "com.baloyi.mrdvendorlocator.tests.\(UUID().uuidString)")
    }

    override func tearDown() {
        try? store.clear()
        super.tearDown()
    }

    func testReadReturnsNilWhenEmpty() {
        XCTAssertNil(store.read())
    }

    func testSaveThenRead() throws {
        try store.save("abc123")

        XCTAssertEqual(store.read(), "abc123")
    }

    func testSaveOverwritesExistingToken() throws {
        try store.save("first")
        try store.save("second")

        XCTAssertEqual(store.read(), "second")
    }

    func testClearRemovesToken() throws {
        try store.save("abc123")

        try store.clear()

        XCTAssertNil(store.read())
    }

    func testClearWhenEmptyDoesNotThrow() {
        XCTAssertNoThrow(try store.clear())
    }
}
