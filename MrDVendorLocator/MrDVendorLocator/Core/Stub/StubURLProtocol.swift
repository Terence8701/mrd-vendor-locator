//
//  StubURLProtocol.swift
//  MrDVendorLocator
//

import Foundation
import os

/// A local stand-in for the Mr D REST API, plugged into a dedicated `URLSession`.
///
/// Serves `GET https://api.mrd.local/v1/vendors` from the bundled `vendors.json`, requires a
/// `Bearer` token (401 otherwise), adds latency so loading states are visible, and can simulate
/// failures for demoing error states.
nonisolated final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    static let baseURL: URL = {
        guard let url = URL(string: "https://api.mrd.local") else {
            preconditionFailure("The stub base URL is a constant and must be valid.")
        }
        return url
    }()

    enum Scenario: String, CaseIterable, Sendable {
        case success
        case serverError
        case offline
    }

    struct Configuration: Sendable {
        var scenario: Scenario = .success
        var latency: Duration = .milliseconds(600)
    }

    private static let state = OSAllocatedUnfairLock(initialState: Configuration())

    /// Shared across all stubbed sessions; changed by the debug toggle and by tests.
    static var configuration: Configuration {
        get { state.withLock { $0 } }
        set { state.withLock { $0 = newValue } }
    }

    private var loadingTask: Task<Void, Never>?

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host() == baseURL.host()
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let request = self.request
        let configuration = Self.configuration
        loadingTask = Task { [weak self] in
            try? await Task.sleep(for: configuration.latency)
            guard !Task.isCancelled, let self else { return }
            self.respond(to: request, scenario: configuration.scenario)
        }
    }

    override func stopLoading() {
        loadingTask?.cancel()
    }

    private func respond(to request: URLRequest, scenario: Scenario) {
        guard let url = request.url else { return fail(with: URLError(.badURL)) }

        switch scenario {
        case .offline:
            return fail(with: URLError(.notConnectedToInternet))
        case .serverError:
            return send(status: 500, url: url)
        case .success:
            break
        }

        guard request.httpMethod == "GET", url.path() == "/v1/vendors" else {
            return send(status: 404, url: url)
        }
        guard Self.hasBearerToken(request) else {
            return send(status: 401, url: url)
        }
        guard let body = Self.vendorsJSON() else {
            return send(status: 500, url: url)
        }
        send(status: 200, url: url, body: body)
    }

    private func send(status: Int, url: URL, body: Data? = nil) {
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        ) else { return fail(with: URLError(.badServerResponse)) }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let body { client?.urlProtocol(self, didLoad: body) }
        client?.urlProtocolDidFinishLoading(self)
    }

    private func fail(with error: URLError) {
        client?.urlProtocol(self, didFailWithError: error)
    }

    private static func hasBearerToken(_ request: URLRequest) -> Bool {
        guard let header = request.value(forHTTPHeaderField: "Authorization"),
              header.hasPrefix("Bearer ") else { return false }
        return !header.dropFirst("Bearer ".count).trimmingCharacters(in: .whitespaces).isEmpty
    }

    private static func vendorsJSON() -> Data? {
        // `Bundle(for:)` resolves to the app bundle in both the app and the hosted test bundle.
        guard let url = Bundle(for: StubURLProtocol.self).url(forResource: "vendors", withExtension: "json") else {
            return nil
        }
        return try? Data(contentsOf: url)
    }
}

extension URLSession {
    /// An ephemeral session whose requests are answered by `StubURLProtocol`.
    /// Scoped to this session rather than registered globally, so nothing else gets intercepted.
    nonisolated static func stubbed() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
