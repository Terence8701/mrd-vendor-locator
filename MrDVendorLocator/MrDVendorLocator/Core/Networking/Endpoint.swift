//
//  Endpoint.swift
//  MrDVendorLocator
//

import Foundation

/// A typed description of one API call. `Response` is the type the body decodes to.
nonisolated struct Endpoint<Response: Decodable & Sendable>: Sendable {
    enum Method: String, Sendable {
        case get = "GET"
    }

    let path: String
    let method: Method
    let requiresAuth: Bool
}

extension Endpoint where Response == VendorsResponse {
    static var vendors: Endpoint {
        Endpoint(path: "/v1/vendors", method: .get, requiresAuth: true)
    }
}
