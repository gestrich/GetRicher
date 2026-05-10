import ClientService
import SwiftUI

struct AdminBuildStatusView: View {
    @Environment(AdminModel.self) var adminModel
    @Environment(SettingsModel.self) var settingsModel

    var body: some View {
        List {
            if adminModel.isLoading {
                ProgressView()
            } else if let status = adminModel.buildStatus {
                if status.runs.isEmpty {
                    Text("No recent builds found.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(status.runs) { run in
                        BuildRunRow(run: run)
                    }
                }
            } else {
                Text("Tap refresh to load build status.")
                    .foregroundColor(.secondary)
            }

            if let error = adminModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
            }
        }
        .navigationTitle("Build Status")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await adminModel.loadBuildStatus(backendURL: settingsModel.backendURL) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            await adminModel.loadBuildStatus(backendURL: settingsModel.backendURL)
        }
    }
}

private struct BuildRunRow: View {
    let run: BuildRun

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                statusIcon
                Text(run.name)
                    .font(.body)
                Spacer()
                Text(shortDate(run.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(run.commitMessage.components(separatedBy: "\n").first ?? run.commitMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }

    private var statusIcon: some View {
        let (systemName, color): (String, Color) = {
            switch run.conclusion {
            case "success": return ("checkmark.circle.fill", .green)
            case "failure": return ("xmark.circle.fill", .red)
            case "cancelled": return ("minus.circle.fill", .orange)
            default:
                if run.status == "in_progress" { return ("arrow.clockwise.circle.fill", .blue) }
                return ("circle.fill", .secondary)
            }
        }()
        return Image(systemName: systemName).foregroundColor(color)
    }

    private func shortDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: iso) else { return iso }
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .abbreviated
        return rel.localizedString(for: date, relativeTo: Date())
    }
}
