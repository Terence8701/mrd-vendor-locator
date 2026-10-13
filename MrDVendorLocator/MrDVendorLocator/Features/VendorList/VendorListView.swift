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

        case .loaded:
            vendorList
        }
    }

    private var vendorList: some View {
        @Bindable var viewModel = viewModel
        let vendors = viewModel.visibleVendors

        return ScrollViewReader { proxy in
            List {
                Section {
                    ForEach(vendors) { vendor in
                        VendorRowView(
                            vendor: vendor,
                            onSelect: { onSelect(vendor) },
                            onToggleFavorite: { Task { await viewModel.toggleFavorite(vendor.id) } }
                        )
                        .id(vendor.id)
                        .listRowBackground(vendor.id == viewModel.selectedVendorID ? Color.accentColor.opacity(0.12) : nil)
                    }
                } header: {
                    VendorFilterBar(filter: $viewModel.filter, count: vendors.count)
                }
            }
            .listStyle(.plain)
            .overlay {
                if vendors.isEmpty {
                    noMatches
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search vendors or addresses")
            .refreshable { await viewModel.reload() }
            // Scroll to a vendor picked on the map.
            .onChange(of: viewModel.listFocus) { _, focus in
                guard let focus else { return }
                withAnimation { proxy.scrollTo(focus.vendorID, anchor: .center) }
            }
        }
    }

    @ViewBuilder
    private var noMatches: some View {
        if !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView.search(text: viewModel.searchText)
        } else {
            ContentUnavailableView(
                "No favorites yet",
                systemImage: "heart",
                description: Text("Tap the heart on a vendor to add it here.")
            )
        }
    }

    private var transientErrorIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.transientError != nil },
            set: { if !$0 { viewModel.transientError = nil } }
        )
    }
}

/// All / Favorites chips and the number of vendors shown.
private struct VendorFilterBar: View {
    @Binding var filter: VendorsViewModel.Filter
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(VendorsViewModel.Filter.allCases) { option in
                Button {
                    withAnimation(.snappy) { filter = option }
                } label: {
                    Text(option.rawValue)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .foregroundStyle(filter == option ? Color.white : Color.primary)
                        .background(
                            filter == option ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.fill.tertiary),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(filter == option ? .isSelected : [])
            }

            Spacer()

            // Explicit plural: automatic inflection turns "vendor" into "venders".
            Text(count == 1 ? "1 vendor" : "\(count) vendors")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
        .textCase(nil)
        .padding(.vertical, 6)
    }
}
