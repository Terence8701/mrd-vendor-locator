//
//  APIClient.swift
//  MrDVendorLocator
//

import Foundation

/// Sends typed requests. View models and repositories depend on this, never on `URLSession`.
nonisolated protocol APIClient: Sendable {
    /// - Throws: `APIError` on failure, or `CancellationError` if the task was cancelled.
    func send<Response>(_ endpoint: Endpoint<Response>) async throws -> Response
}

extension JSONDecoder {
    /// The decoder for API responses: ISO 8601 dates, e.g. `2026-09-28T12:00:00Z`.
    nonisolated static func api() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
