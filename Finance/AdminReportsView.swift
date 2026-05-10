import FinanceCoreSDK
import SwiftUI

struct AdminReportsView: View {
    @Environment(AdminModel.self) var adminModel
    @Environment(SettingsModel.self) var settingsModel
    @State private var reportToDelete: String?
    @State private var showingDeleteAlert = false

    var body: some View {
        List {
            if adminModel.isLoading {
                ProgressView()
            } else if adminModel.reports.isEmpty {
                Text("No reports found.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(adminModel.reports, id: \.id) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.headline)
                        Text(item.summary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        HStack {
                            Text(item.status.rawValue.capitalized)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(item.status == .pending ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                                .foregroundColor(item.status == .pending ? .orange : .green)
                                .clipShape(Capsule())
                            Text(item.createdAt)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            reportToDelete = item.id
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            if let error = adminModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
            }
        }
        .navigationTitle("Reports")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await adminModel.loadReports(backendURL: settingsModel.backendURL) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            await adminModel.loadReports(backendURL: settingsModel.backendURL)
        }
        .alert("Delete Report", isPresented: $showingDeleteAlert, presenting: reportToDelete) { id in
            Button("Delete", role: .destructive) {
                Task { await adminModel.deleteReport(id: id, backendURL: settingsModel.backendURL) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Delete this report permanently?")
        }
    }
}
