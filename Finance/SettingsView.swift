import SwiftUI

struct SettingsView: View {
    @Environment(SettingsModel.self) var settingsModel
    @State private var apiToken: String = ""
    @AppStorage("demoMode") private var isDemoMode: Bool = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
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
                    Toggle("Demo Mode", isOn: $isDemoMode)
                } header: {
                    Text("Demo")
                } footer: {
                    Text("Uses sample data instead of real API calls. Restart the app after toggling.")
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
