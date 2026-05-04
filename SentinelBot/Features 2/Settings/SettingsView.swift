//
//  SettingsView.swift
//  SentinelBot
//
//  Broker configuration form. Changes are held in SettingsViewModel until
//  the user taps Save — nothing is written to disk until then.
//

import SwiftUI

struct SettingsView: View {

    @StateObject private var viewModel: SettingsViewModel
    @State private var showResetAlert = false
    @State private var showClearDataAlert = false

    // Port and keepAlive are UInt16 so we bridge through String bindings
    @State private var portText: String = ""
    @State private var keepAliveText: String = ""

    init(persistenceService: PersistenceServiceProtocol) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(persistenceService: persistenceService))
    }

    var body: some View {
        NavigationStack {
            Form {
                brokerSection
                authSection
                advancedSection
                dangerSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { saveToolbarButton }
            .onAppear { syncTextFields() }
            .onChange(of: portText) { new in
                if let value = UInt16(new) { viewModel.config.port = value }
            }
            .onChange(of: keepAliveText) { new in
                if let value = UInt16(new) { viewModel.config.keepAliveSeconds = value }
            }
            .safeAreaInset(edge: .bottom) {
                feedbackBar
            }
        }
        .alert("Reset to Defaults?", isPresented: $showResetAlert) {
            Button("Reset", role: .destructive) {
                viewModel.resetToDefaults()
                syncTextFields()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Broker settings will be restored to factory defaults. Saved data is kept.")
        }
        .alert("Clear All Data?", isPresented: $showClearDataAlert) {
            Button("Clear All", role: .destructive) {
                viewModel.resetAllData()
                syncTextFields()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All stored settings and preferences will be permanently deleted.")
        }
    }

    // MARK: Sections

    private var brokerSection: some View {
        Section {
            LabeledContent("Host") {
                TextField("raspberrypi.local", text: $viewModel.config.host)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }
            LabeledContent("Port") {
                TextField("1883", text: $portText)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .frame(width: 80)
            }
            Toggle("Use TLS", isOn: $viewModel.config.useTLS)
        } header: {
            Text("Broker")
        } footer: {
            if let err = viewModel.validationError {
                Text(err)
                    .foregroundStyle(Color.Theme.danger)
            } else {
                Text("Hostname or IP address of your Mosquitto broker.")
            }
        }
    }

    private var authSection: some View {
        Section("Authentication") {
            LabeledContent("Username") {
                TextField("Optional", text: usernameBinding)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            LabeledContent("Password") {
                SecureField("Optional", text: passwordBinding)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var advancedSection: some View {
        Section("Advanced") {
            LabeledContent("Keep-alive (s)") {
                TextField("30", text: $keepAliveText)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .frame(width: 60)
            }
            LabeledContent("Client ID") {
                Text(viewModel.config.clientID)
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.Theme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Button("Regenerate Client ID") {
                viewModel.regenerateClientID()
            }
            .foregroundStyle(Color.Theme.info)
        }
    }

    private var dangerSection: some View {
        Section("Reset") {
            Button("Reset to Defaults") {
                showResetAlert = true
            }
            .foregroundStyle(Color.Theme.warning)

            Button("Clear All Stored Data", role: .destructive) {
                showClearDataAlert = true
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var saveToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                viewModel.save()
            }
            .disabled(!viewModel.canSave)
            .fontWeight(.semibold)
        }
    }

    // MARK: Feedback bar

    @ViewBuilder
    private var feedbackBar: some View {
        if viewModel.saveSuccess {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.Theme.success)
                Text("Settings saved")
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if let err = viewModel.saveError {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.Theme.danger)
                Text(err)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: Optional String bindings

    private var usernameBinding: Binding<String> {
        Binding(
            get: { viewModel.config.username ?? "" },
            set: { viewModel.config.username = $0.isEmpty ? nil : $0 }
        )
    }

    private var passwordBinding: Binding<String> {
        Binding(
            get: { viewModel.config.password ?? "" },
            set: { viewModel.config.password = $0.isEmpty ? nil : $0 }
        )
    }

    // MARK: Helpers

    private func syncTextFields() {
        portText = String(viewModel.config.port)
        keepAliveText = String(viewModel.config.keepAliveSeconds)
    }
}

// MARK: - Preview

#Preview {
    SettingsView(persistenceService: PersistenceService())
}
