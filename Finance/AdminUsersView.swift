import ClientService
import SwiftUI

struct AdminUsersView: View {
    @Environment(AdminModel.self) var adminModel
    @Environment(SettingsModel.self) var settingsModel
    @State private var userToDelete: AdminUserInfo?
    @State private var showingDeleteAlert = false
    @State private var lmTokenTarget: AdminUserInfo?
    @State private var newLMToken = ""
    @State private var showingLMTokenSheet = false

    var body: some View {
        List {
            if adminModel.isLoading {
                ProgressView()
            } else if adminModel.users.isEmpty {
                Text("No users found.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(adminModel.users, id: \.username) { user in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.username)
                            .font(.headline)
                        Text(user.createdAt)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(user.hasLMToken ? "LM Token: set" : "LM Token: not set")
                            .font(.caption2)
                            .foregroundColor(user.hasLMToken ? .green : .orange)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            userToDelete = user
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            lmTokenTarget = user
                            newLMToken = ""
                            showingLMTokenSheet = true
                        } label: {
                            Label("Set LM Token", systemImage: "key")
                        }
                        .tint(.blue)
                    }
                }
            }

            if let error = adminModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
            }
        }
        .navigationTitle("Users")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await adminModel.loadUsers(backendURL: settingsModel.backendURL) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            await adminModel.loadUsers(backendURL: settingsModel.backendURL)
        }
        .alert("Delete User", isPresented: $showingDeleteAlert, presenting: userToDelete) { user in
            Button("Delete", role: .destructive) {
                Task { await adminModel.deleteUser(username: user.username, backendURL: settingsModel.backendURL) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { user in
            Text("Delete \(user.username) and all their data? This cannot be undone.")
        }
        .sheet(isPresented: $showingLMTokenSheet) {
            NavigationStack {
                Form {
                    Section("New Lunch Money Token") {
                        TextField("Token", text: $newLMToken)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    if let error = adminModel.errorMessage {
                        Text(error).foregroundColor(.red).font(.footnote)
                    }
                }
                .navigationTitle("Update LM Token")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingLMTokenSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            guard let user = lmTokenTarget else { return }
                            Task {
                                await adminModel.updateLMToken(username: user.username, lmToken: newLMToken, backendURL: settingsModel.backendURL)
                                if adminModel.errorMessage == nil { showingLMTokenSheet = false }
                            }
                        }
                        .disabled(newLMToken.isEmpty)
                    }
                }
            }
        }
    }
}
