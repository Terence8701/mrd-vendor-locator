//
//  VendorsViewModel.swift
//  MrDVendorLocator
//

import Foundation
import Observation
import os

/// Shared by the list and map tabs, so loading, favorites and selection stay in sync.
@Observable
@MainActor
final class VendorsViewModel {
    /// A request for the map to focus a vendor. Each call to `select(_:)` makes a new one,
    /// so selecting the same vendor again still re-centres the map.
    nonisolated struct Selection: Equatable, Sendable {
        let vendorID: Vendor.ID
        let id = UUID()
    }

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case favorites = "Favorites"

        var id: Self { self }
    }

    private(set) var state: ViewState<[Vendor]> = .idle
    private(set) var selection: Selection?
    /// A request for the list to scroll to a vendor, made from the map.
    private(set) var listFocus: Selection?
    var searchText = ""
    var filter: Filter = .all
    /// True while vendors without coordinates are being geocoded.
    private(set) var isResolvingLocations = false
    /// An error that shouldn't replace content already on screen, e.g. a failed
    /// refresh or favorite toggle. Shown as an alert.
    var transientError: UserFacingError?

    @ObservationIgnored private let repository: VendorRepository
    @ObservationIgnored private let geocoder: Geocoding
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    /// Internal (not private) so tests can await geocoding.
    @ObservationIgnored private(set) var locationTask: Task<Void, Never>?

    nonisolated private static let logger = Logger(subsystem: "com.baloyi.mrdvendorlocator", category: "Geocoding")

    init(repository: VendorRepository, geocoder: Geocoding) {
        self.repository = repository
        self.geocoder = geocoder
    }

    var selectedVendorID: Vendor.ID? {
        selection?.vendorID
    }

    var vendors: [Vendor] {
        if case .loaded(let vendors) = state { vendors } else { [] }
    }

    var selectedVendor: Vendor? {
        vendors.first { $0.id == selectedVendorID }
    }

    /// The vendors the list shows: the current filter, then the search text matched
    /// against name and address, ignoring case and accents.
    var visibleVendors: [Vendor] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return vendors.filter { vendor in
            (filter == .all || vendor.isFavorite)
                && (query.isEmpty
                    || vendor.name.localizedStandardContains(query)
                    || vendor.address.localizedStandardContains(query))
        }
    }

    var isFiltering: Bool {
        filter != .all || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        selection = Selection(vendorID: vendorID)
    }

    func clearSelection() {
        selection = nil
    }

    /// Asks the list to scroll to a vendor. Clears the search and filter first if they
    /// would hide it.
    func revealInList(_ vendorID: Vendor.ID) {
        if !visibleVendors.contains(where: { $0.id == vendorID }) {
            searchText = ""
            filter = .all
        }
        listFocus = Selection(vendorID: vendorID)
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
            resolveMissingCoordinates()
        } catch is CancellationError {
            // Superseded by a newer load, which owns the state now.
        } catch {
            let error = UserFacingError(error)
            // A 401 means the session is gone, so vendors already on screen are cleared too.
            if hasContent && error.action != .openSettings {
                transientError = error
            } else {
                locationTask?.cancel()
                isResolvingLocations = false
                state = .failed(error)
            }
        }
    }

    /// Geocodes every vendor without a coordinate, concurrently. The list is already on
    /// screen; map pins appear as each lookup finishes. A failed lookup leaves that vendor
    /// off the map rather than failing the screen.
    private func resolveMissingCoordinates() {
        locationTask?.cancel()
        let pending = vendors.filter { $0.coordinate == nil }.map { (id: $0.id, address: $0.address) }
        guard !pending.isEmpty else {
            isResolvingLocations = false
            return
        }

        isResolvingLocations = true
        let geocoder = self.geocoder
        locationTask = Task {
            await withTaskGroup(of: (Vendor.ID, Coordinate?).self) { group in
                for vendor in pending {
                    group.addTask {
                        do {
                            return (vendor.id, try await geocoder.coordinate(for: vendor.address))
                        } catch {
                            Self.logger.error("Geocoding failed for \(vendor.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                            return (vendor.id, nil)
                        }
                    }
                }
                for await (vendorID, coordinate) in group {
                    guard !Task.isCancelled, let coordinate else { continue }
                    updateVendor(vendorID) { $0.coordinate = coordinate }
                }
            }
            if !Task.isCancelled { isResolvingLocations = false }
        }
    }

    private func updateVendor(_ vendorID: Vendor.ID, _ change: (inout Vendor) -> Void) {
        guard case .loaded(var vendors) = state,
              let index = vendors.firstIndex(where: { $0.id == vendorID }) else { return }
        change(&vendors[index])
        state = .loaded(vendors)
    }
}
