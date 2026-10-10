//
//  MrDVendorLocatorTests.swift
//  MrDVendorLocatorTests
//
//  Created by Terence Baloyi on 2026/10/10.
//

import XCTest
@testable import MrDVendorLocator

final class MrDVendorLocatorTests: XCTestCase {

    func testAppModuleLoads() {
        XCTAssertNotNil(Bundle(for: Self.self))
    }
}
