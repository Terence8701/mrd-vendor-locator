//
//  VendorListView.swift
//  MrDVendorLocator
//

import SwiftUI

struct VendorListView: View {
    @Environment(VendorsViewModel.self) private var viewModel

    /// Called when a vendor is tapped; the root view switches to the map.
    let onSelect: (Vendor) -> Void
    /// Called from the 401 error state; the root view switches to Settings.
    let onOpenSettings: () -> Void

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Vendors")
        }
        .task { await viewModel.loadIfNeeded() }
        .alert(
            viewModel.transientError?.title ?? "",
            isPresented: transientErrorIsPresented,
            presenting: viewModel.transientError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.message)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("Loading vendors…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .empty:
            ContentUnavailableView {
                Label("No vendors yet", systemImage: "storefront")
            } description: {
                Text("There are no vendors near you right now.")
            } actions: {
                Button("Refresh") { Task { await viewModel.reload() } }
            }

        case .failed(let error):
            ContentUnavailableView {
                Label(error.title, systemImage: error.action == .openSettings ? "lock" : "exclamationmark.triangle")
            } description: {
                Text(error.message)
            } actions: {
                switch error.action {
                case .retry:
                    Button("Try Again") { Task { await viewModel.reload() } }
                        .buttonStyle(.borderedProminent)
                case .openSettings:
                    Button("Open Settings", action: onOpenSettings)
                        .buttonStyle(.borderedProminent)
                }
            }

        case .loaded(let vendors):
            List(vendors) { vendor in
                VendorRowView(
                    vendor: vendor,
                    onSelect: { onSelect(vendor) },
                    onToggleFavorite: { Task { await viewModel.toggleFavorite(vendor.id) } }
                )
            }
            .listStyle(.plain)
            .refreshable { await viewModel.reload() }
        }
    }

    private var transientErrorIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.transientError != nil },
            set: { if !$0 { viewModel.transientError = nil } }
        )
    }
}
