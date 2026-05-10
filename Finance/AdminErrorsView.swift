import ClientService
import SwiftUI

struct AdminErrorsView: View {
    @Environment(AdminModel.self) var adminModel
    @Environment(SettingsModel.self) var settingsModel

    var body: some View {
        List {
            if adminModel.isLoading {
                ProgressView()
            } else if let response = adminModel.errors {
                if !response.message.isEmpty {
                    Section("Status") {
                        Text(response.message)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                if response.errors.isEmpty {
                    Section("Errors") {
                        Text("No errors recorded.")
                            .foregroundColor(.secondary)
                    }
                } else {
                    Section("Errors") {
                        ForEach(response.errors, id: \.self) { error in
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            } else {
                Text("Tap refresh to load errors.")
                    .foregroundColor(.secondary)
            }

            if let error = adminModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
            }
        }
        .navigationTitle("Errors")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await adminModel.loadErrors(backendURL: settingsModel.backendURL) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            await adminModel.loadErrors(backendURL: settingsModel.backendURL)
        }
    }
}
