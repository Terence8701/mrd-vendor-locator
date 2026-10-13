//
//  SettingsView.swift
//  MrDVendorLocator
//

import SwiftUI

struct SettingsView: View {
    @Environment(SettingsViewModel.self) private var viewModel
    @State private var isConfirmingClear = false

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                Section {
                    HStack {
                        Group {
                            if viewModel.isTokenRevealed {
                                TextField("Session token", text: $viewModel.draftToken, prompt: Text("e.g. mrD_token_example_123"))
                            } else {
                                SecureField("Session token", text: $viewModel.draftToken, prompt: Text("e.g. mrD_token_example_123"))
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                        .submitLabel(.done)
                        .onSubmit { Task { await viewModel.save() } }

                        Button {
                            viewModel.isTokenRevealed.toggle()
                        } label: {
                            Image(systemName: viewModel.isTokenRevealed ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(viewModel.isTokenRevealed ? "Hide token" : "Show token")
                    }

                    Button("Save") { Task { await viewModel.save() } }
                        .disabled(!viewModel.canSave)

                    Button("Clear Token", role: .destructive) { isConfirmingClear = true }
                        .disabled(!viewModel.hasSavedToken)
                } header: {
                    Text("Session")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(
                            viewModel.hasSavedToken ? "Token saved" : "No token saved",
                            systemImage: viewModel.hasSavedToken ? "checkmark.shield" : "exclamationmark.shield"
                        )
                        Text("Stored securely in the iOS Keychain on this device only.")
                        if let error = viewModel.errorMessage {
                            Text(error).foregroundStyle(.red)
                        }
                    }
                }

                #if DEBUG
                StubScenarioSection()
                #endif
            }
            .navigationTitle("Settings")
            .confirmationDialog("Clear the session token?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
                Button("Clear Token", role: .destructive) { Task { await viewModel.clear() } }
            } message: {
                Text("Vendors won't load until you add a token again.")
            }
        }
    }
}

#if DEBUG
/// Debug-only control to make the stub API fail, for demoing error states.
private struct StubScenarioSection: View {
    @State private var scenario = StubURLProtocol.configuration.scenario

    var body: some View {
        Section {
            Picker("Stub API response", selection: $scenario) {
                Text("Success").tag(StubURLProtocol.Scenario.success)
                Text("Server error (500)").tag(StubURLProtocol.Scenario.serverError)
                Text("Offline").tag(StubURLProtocol.Scenario.offline)
            }
            .onChange(of: scenario) { _, newValue in
                StubURLProtocol.configuration.scenario = newValue
            }
        } header: {
            Text("Developer")
        } footer: {
            Text("Simulates API responses to demonstrate error handling. Available in debug builds only.")
        }
    }
}
#endif
