import SwiftUI

struct SettingsView: View {
    @Environment(SettingsModel.self) var settingsModel
    @State private var apiToken: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settingsModel
        NavigationStack {
            Form {
                Section {
                    Picker("Data Source", selection: $settings.appMode) {
                        Text("Demo Data").tag(AppMode.demo)
                        Text("API Token").tag(AppMode.token)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Mode")
                } footer: {
                    if settingsModel.isDemoMode {
                        Text("Using sample data. Switch to API Token to connect your Lunch Money account.")
                    } else {
                        Text("Using your Lunch Money API token for real data.")
                    }
                }

                if !settingsModel.isDemoMode {
                    Section {
                        SecureField("API Token", text: $apiToken)
                            .textContentType(.password)

                        Button("Save Token") {
                            settingsModel.saveToken(apiToken)
                        }
                        .disabled(apiToken.isEmpty)
                    } header: {
                        Text("Lunch Money API")
                    } footer: {
                        Text("Enter your Lunch Money API token. It will be securely stored in the keychain.")
                    }

                    if settingsModel.isSaved {
                        Section {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Token saved successfully")
                            }
                        }
                    }

                    if let error = settingsModel.errorMessage {
                        Section {
                            Text(error)
                                .foregroundColor(.red)
                        }
                    }

                    Section {
                        Button("Delete Token", role: .destructive) {
                            settingsModel.deleteToken()
                            apiToken = ""
                        }
                    } footer: {
                        Text("Remove the API token from keychain")
                    }
                }

                Section("Management") {
                    NavigationLink("Categories") {
                        CategoryListView()
                    }
                    NavigationLink("Vendors") {
                        VendorListView(accountId: nil)
                    }
                }

                Section("Diagnostics") {
                    NavigationLink("Logs") {
                        LogsView()
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                settingsModel.loadToken()
                if let token = settingsModel.currentToken {
                    apiToken = token
                }
            }
        }
    }
}
