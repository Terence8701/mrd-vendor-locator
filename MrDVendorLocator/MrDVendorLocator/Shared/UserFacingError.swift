//
//  UserFacingError.swift
//  MrDVendorLocator
//

import Foundation

/// An error ready to show in the UI: friendly copy plus the action the user can take.
nonisolated struct UserFacingError: Error, Equatable, Sendable {
    enum Action: Equatable, Sendable {
        /// Try the same request again.
        case retry
        /// The session token is missing or invalid; send the user to Settings.
        case openSettings
    }

    let title: String
    let message: String
    let action: Action
}

extension UserFacingError {
    /// Maps any error from the data layer. Unknown errors get generic, retryable copy.
    init(_ error: any Error) {
        if let error = error as? UserFacingError {
            self = error
        } else if let error = error as? APIError {
            self.init(apiError: error)
        } else {
            self.init(
                title: "Something went wrong",
                message: "Please try again.",
                action: .retry
            )
        }
    }

    static let favoriteUpdateFailed = UserFacingError(
        title: "Couldn't update favorite",
        message: "Your change wasn't saved. Please try again.",
        action: .retry
    )

    private init(apiError error: APIError) {
        switch error {
        case .unauthorized:
            self.init(
                title: "Session required",
                message: "Add a session token in Settings to load vendors.",
                action: .openSettings
            )
        case .offline:
            self.init(
                title: "You're offline",
                message: "Check your internet connection and try again.",
                action: .retry
            )
        case .server:
            self.init(
                title: "Something went wrong",
                message: "We couldn't reach Mr D right now. Please try again.",
                action: .retry
            )
        case .decoding, .invalidResponse, .transport:
            self.init(
                title: "Couldn't load vendors",
                message: "We received an unexpected response. Please try again.",
                action: .retry
            )
        }
    }
}
