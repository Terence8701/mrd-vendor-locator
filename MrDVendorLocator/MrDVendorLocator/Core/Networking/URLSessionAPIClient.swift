//
//  URLSessionAPIClient.swift
//  MrDVendorLocator
//

import Foundation

/// `APIClient` backed by a real `URLSession`. In this app the session is configured with
/// `StubURLProtocol`, so requests, headers and status codes all go through the normal path.
nonisolated final class URLSessionAPIClient: APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let tokenStore: TokenStore

    init(baseURL: URL, session: URLSession, tokenStore: TokenStore) {
        self.baseURL = baseURL
        self.session = session
        self.tokenStore = tokenStore
    }

    func send<Response>(_ endpoint: Endpoint<Response>) async throws -> Response {
        let request = makeRequest(for: endpoint)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw Self.map(error)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        switch http.statusCode {
        case 200..<300:
            break
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.server(statusCode: http.statusCode)
        }

        do {
            return try JSONDecoder.api().decode(Response.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    private func makeRequest<Response>(for endpoint: Endpoint<Response>) -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: endpoint.path))
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // Read the token per request so a token saved or cleared in Settings applies immediately.
        if endpoint.requiresAuth, let token = tokenStore.read() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private static func map(_ error: URLError) -> APIError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            .offline
        default:
            .transport(error.code)
        }
    }
}
