//
//  VendorsViewModel.swift
//  MrDVendorLocator
//

import Foundation
import Observation

/// Shared by the list and map tabs, so loading, favorites and selection stay in sync.
@Observable
@MainActor
final class VendorsViewModel {
    private(set) var state: ViewState<[Vendor]> = .idle
    /// The vendor the map should focus on. Set from the list.
    private(set) var selectedVendorID: Vendor.ID?
    /// An error that shouldn't replace content already on screen, e.g. a failed
    /// refresh or favorite toggle. Shown as an alert.
    var transientError: UserFacingError?

    @ObservationIgnored private let repository: VendorRepository
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    init(repository: VendorRepository) {
        self.repository = repository
    }

    var vendors: [Vendor] {
        if case .loaded(let vendors) = state { vendors } else { [] }
    }

    /// Loads once, on first appearance.
    func loadIfNeeded() async {
        guard case .idle = state else { return }
        await reload()
    }

    /// Cancels any in-flight load and starts a new one. Awaitable so `.refreshable`
    /// keeps its spinner until the load finishes.
    func reload() async {
        loadTask?.cancel()
        let task = Task { await performLoad() }
        loadTask = task
        await task.value
    }

    func select(_ vendorID: Vendor.ID) {
        selectedVendorID = vendorID
    }

    /// Updates the UI immediately, then persists; rolls back if saving fails.
    func toggleFavorite(_ vendorID: Vendor.ID) async {
        guard let vendor = vendors.first(where: { $0.id == vendorID }) else { return }
        let newValue = !vendor.isFavorite
        updateVendor(vendorID) { $0.isFavorite = newValue }

        do {
            try await repository.setFavorite(newValue, for: vendorID)
        } catch {
            updateVendor(vendorID) { $0.isFavorite = !newValue }
            transientError = .favoriteUpdateFailed
        }
    }

    private func performLoad() async {
        // Keep showing existing vendors during a refresh; only a first load shows a spinner.
        let hasContent = !vendors.isEmpty
        if !hasContent { state = .loading }

        do {
            let vendors = try await repository.fetchVendors()
            try Task.checkCancellation()
            state = vendors.isEmpty ? .empty : .loaded(vendors)
        } catch is CancellationError {
            // Superseded by a newer load, which owns the state now.
        } catch {
            let error = UserFacingError(error)
            if hasContent {
                transientError = error
            } else {
                state = .failed(error)
            }
        }
    }

    private func updateVendor(_ vendorID: Vendor.ID, _ change: (inout Vendor) -> Void) {
        guard case .loaded(var vendors) = state,
              let index = vendors.firstIndex(where: { $0.id == vendorID }) else { return }
        change(&vendors[index])
        state = .loaded(vendors)
    }
}
