//
//  ViewState.swift
//  MrDVendorLocator
//

import Foundation

/// The load state of a screen. Views switch over this instead of juggling
/// separate `isLoading` / `error` / `items` properties.
nonisolated enum ViewState<Value> {
    case idle
    case loading
    case loaded(Value)
    case empty
    case failed(UserFacingError)
}

extension ViewState: Equatable where Value: Equatable {}
extension ViewState: Sendable where Value: Sendable {}
