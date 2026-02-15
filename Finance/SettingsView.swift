//
//  SettingsView.swift
//  Finance
//
//  Created by Bill Gestrich on 1/14/26.
//

import SwiftUI

struct SettingsView: View {
    @State private var apiToken: String = ""
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("API Token", text: $apiToken)
                        .textContentType(.password)

                    Button("Save Token") {
                        saveToken()
                    }
                    .disabled(apiToken.isEmpty)
                } header: {
                    Text("Lunch Money API")
                } footer: {
                    Text("Enter your Lunch Money API token. It will be securely stored in the keychain.")
                }

                if showSuccess {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Token saved successfully")
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button("Delete Token", role: .destructive) {
                        deleteToken()
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
                loadExistingToken()
            }
        }
    }

    private func loadExistingToken() {
        if let token = KeychainService.shared.getAPIToken() {
            apiToken = token
        }
    }

    private func saveToken() {
        do {
            try KeychainService.shared.saveAPIToken(apiToken)
            showSuccess = true
            errorMessage = nil

            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                showSuccess = false
            }
        } catch {
            errorMessage = "Failed to save token: \(error.localizedDescription)"
            showSuccess = false
        }
    }

    private func deleteToken() {
        do {
            try KeychainService.shared.deleteAPIToken()
            apiToken = ""
            showSuccess = false
            errorMessage = nil
        } catch {
            errorMessage = "Failed to delete token: \(error.localizedDescription)"
        }
    }
}

#Preview {
    SettingsView()
}
