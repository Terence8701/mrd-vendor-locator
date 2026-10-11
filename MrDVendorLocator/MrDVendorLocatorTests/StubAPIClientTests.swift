//
//  StubAPIClientTests.swift
//  MrDVendorLocatorTests
//

import XCTest
@testable import MrDVendorLocator

/// Exercises the real `URLSessionAPIClient` against `StubURLProtocol`: headers,
/// status codes, decoding and error mapping all run as they do in the app.
final class StubAPIClientTests: XCTestCase {

    override func setUp() {
        super.setUp()
        StubURLProtocol.configuration = .init(scenario: .success, latency: .zero)
    }

    override func tearDown() {
        StubURLProtocol.configuration = .init()
        super.tearDown()
    }

    private func makeClient(token: String?) -> URLSessionAPIClient {
        URLSessionAPIClient(
            baseURL: StubURLProtocol.baseURL,
            session: .stubbed(),
            tokenStore: InMemoryTokenStore(token: token)
        )
    }

    func testMissingTokenReturnsUnauthorized() async {
        do {
            _ = try await makeClient(token: nil).send(.vendors)
            XCTFail("Expected a 401")
        } catch {
            XCTAssertEqual(error as? APIError, .unauthorized)
        }
    }

    func testWithTokenReturnsVendors() async throws {
        let response = try await makeClient(token: "test-token").send(.vendors)

        XCTAssertEqual(response.vendors.count, 10)
    }

    func testServerErrorScenarioMapsToServerError() async {
        StubURLProtocol.configuration.scenario = .serverError

        do {
            _ = try await makeClient(token: "test-token").send(.vendors)
            XCTFail("Expected a server error")
        } catch {
            XCTAssertEqual(error as? APIError, .server(statusCode: 500))
        }
    }

    func testOfflineScenarioMapsToOffline() async {
        StubURLProtocol.configuration.scenario = .offline

        do {
            _ = try await makeClient(token: "test-token").send(.vendors)
            XCTFail("Expected an offline error")
        } catch {
            XCTAssertEqual(error as? APIError, .offline)
        }
    }
}
