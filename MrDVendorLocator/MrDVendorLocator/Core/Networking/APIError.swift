//
//  APIError.swift
//  MrDVendorLocator
//

import Foundation

/// Transport-level failures, mapped from `URLError`, HTTP status codes and decoding.
/// Converted to `UserFacingError` before reaching the UI.
nonisolated enum APIError: Error, Equatable, Sendable {
    case unauthorized
    case offline
    case server(statusCode: Int)
    case invalidResponse
    case decoding
    case transport(URLError.Code)
}
