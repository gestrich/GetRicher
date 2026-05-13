import SwiftUI

struct SettingsView: View {
    @Environment(SettingsModel.self) var settingsModel
    @Environment(NotificationsModel.self) var notificationsModel
    @Environment(UserAccountModel.self) var userAccountModel
    @Environment(AdminModel.self) var adminModel
    @State private var reportSent = false
    @State private var reportGenerated = false
    @State private var accountFormMode: AccountFormMode = .login
    @AppStorage("adminUnlocked") private var adminUnlocked: Bool = false

    enum AccountFormMode {
        case login, register
    }
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
                        Picker("", selection: $accountFormMode) {
                            Text("Log In").tag(AccountFormMode.login)
                            Text("Register").tag(AccountFormMode.register)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: accountFormMode) { userAccountModel.errorMessage = nil }
                        TextField("Username", text: $account.username)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .textContentType(.username)
                        SecureField("Password", text: $account.password)
                            .textContentType(.password)
                        Button(accountFormMode == .login ? "Log In" : "Register") {
                            Task {
                                switch accountFormMode {
                                case .login:
                                    await userAccountModel.login(backendURL: settingsModel.backendURL)
                                case .register:
                                    await userAccountModel.register(backendURL: settingsModel.backendURL)
                                }
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
                    NavigationLink("Notification Subscriptions") {
                        NotificationSubscriptionsView()
                    }
                }

                Section("Diagnostics") {
                    NavigationLink("Logs") {
                        LogsView()
                    }
                }

                Section {
                    if adminUnlocked {
                        Button("Generate Report Now") {
                            reportGenerated = false
                            Task {
                                await adminModel.generateReport(backendURL: settingsModel.backendURL)
                                if adminModel.errorMessage == nil {
                                    reportGenerated = true
                                }
                            }
                        }
                        if reportGenerated {
                            Label("Report generated!", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        if let error = adminModel.errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.footnote)
                        }
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
                        NavigationLink("Build Status") {
                            AdminBuildStatusView()
                                .environment(adminModel)
                                .environment(settingsModel)
                        }
                    }
                } header: {
                    Text("Admin")
                        .onLongPressGesture(minimumDuration: 3) {
                            adminUnlocked.toggle()
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
        }
    }
}
