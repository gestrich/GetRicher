import SwiftUI

struct SettingsView: View {
    @Environment(SettingsModel.self) var settingsModel
    @Environment(NotificationsModel.self) var notificationsModel
    @Environment(UserAccountModel.self) var userAccountModel
    @Environment(AdminModel.self) var adminModel
    @State private var reportSent = false
    @State private var showAdminLogin = false
    @State private var pendingAdminPassword = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settingsModel
        NavigationStack {
            Form {
                Section {
                    Picker("Data Source", selection: $settings.appMode) {
                        Text("Demo Data").tag(AppMode.demo)
                        Text("Connected").tag(AppMode.token)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Mode")
                } footer: {
                    if settingsModel.isDemoMode {
                        Text("Using sample data. Switch to Connected to use your account.")
                    } else {
                        Text("Using your account credentials for real data.")
                    }
                }

                Section {
                    TextField("https://...", text: $settings.backendURL)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    if let token = notificationsModel.registeredToken {
                        Button("Re-send Device Token") {
                            Task { await notificationsModel.sendTokenToBackend(token) }
                        }
                    }
                } header: {
                    Text("Backend")
                } footer: {
                    Text("API Gateway URL for data sync and push notification registration.")
                }

                Section {
                    if userAccountModel.isRegistered {
                        LabeledContent("Username", value: userAccountModel.username)
                        Button("Send Report Now") {
                            reportSent = false
                            Task {
                                await userAccountModel.sendReportNow(backendURL: settingsModel.backendURL)
                                if userAccountModel.errorMessage == nil {
                                    reportSent = true
                                }
                            }
                        }
                        if reportSent {
                            Label("Sent!", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        if let error = userAccountModel.errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.footnote)
                        }
                        Button("Sign Out", role: .destructive) {
                            userAccountModel.signOut()
                        }
                    } else {
                        @Bindable var account = userAccountModel
                        TextField("Username", text: $account.username)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .textContentType(.username)
                        SecureField("Password", text: $account.password)
                            .textContentType(.newPassword)
                        Button("Register") {
                            Task {
                                await userAccountModel.register(backendURL: settingsModel.backendURL)
                                if userAccountModel.isRegistered, let token = notificationsModel.registeredToken {
                                    await notificationsModel.sendTokenToBackend(token)
                                }
                            }
                        }
                        .disabled(userAccountModel.username.isEmpty || userAccountModel.password.isEmpty)
                        if let error = userAccountModel.errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.footnote)
                        }
                    }
                } header: {
                    Text("Account")
                } footer: {
                    Text("Register to sync financial data and receive push notifications.")
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

                if adminModel.hasAdminAccess {
                    Section("Admin") {
                        NavigationLink("Users") {
                            AdminUsersView()
                                .environment(adminModel)
                                .environment(settingsModel)
                        }
                        NavigationLink("Reports") {
                            AdminReportsView()
                                .environment(adminModel)
                                .environment(settingsModel)
                        }
                        NavigationLink("Errors") {
                            AdminErrorsView()
                                .environment(adminModel)
                                .environment(settingsModel)
                        }
                        Button("Sign Out Admin", role: .destructive) {
                            adminModel.signOutAdmin()
                        }
                    }
                } else {
                    Section("Admin") {
                        Button("Admin Sign In") {
                            pendingAdminPassword = ""
                            showAdminLogin = true
                        }
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
            .sheet(isPresented: $showAdminLogin) {
                NavigationStack {
                    Form {
                        Section("Admin Password") {
                            SecureField("Password", text: $pendingAdminPassword)
                                .textContentType(.password)
                        }
                    }
                    .navigationTitle("Admin Sign In")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showAdminLogin = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Sign In") {
                                @Bindable var admin = adminModel
                                adminModel.adminPassword = pendingAdminPassword
                                adminModel.saveAdminCredentials()
                                showAdminLogin = false
                            }
                            .disabled(pendingAdminPassword.isEmpty)
                        }
                    }
                }
            }
        }
    }
}
