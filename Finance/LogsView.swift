import LoggingSDK
import SwiftUI

struct LogsView: View {
    @Environment(LogsModel.self) private var model
    @State private var selectedEntry: LogEntry?

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search logs…", text: $model.searchText)
                    .textFieldStyle(.roundedBorder)
                if !model.searchText.isEmpty {
                    Button {
                        model.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if case .loading = model.state {
                ProgressView("Loading logs…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if case .error(let error) = model.state {
                ContentUnavailableView(
                    "Failed to Load Logs",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.filteredItems.isEmpty {
                ContentUnavailableView(
                    "No Log Entries",
                    systemImage: "doc.text",
                    description: Text(
                        model.searchText.isEmpty
                            ? "No logs have been written yet."
                            : "No entries match your search."
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                logList
            }

            Divider()

            HStack {
                Text("\(model.filteredItems.count) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()

                ShareLink(
                    item: model.shareableLogText,
                    subject: Text("GetRicher Logs"),
                    message: Text("App logs from GetRicher")
                ) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.borderless)

                Button(role: .destructive) {
                    model.deleteLogs()
                } label: {
                    Label("Clear", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
                .disabled(model.items.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .navigationTitle("Logs")
        .task { await model.load() }
        .sheet(item: $selectedEntry) { entry in
            LogEntryDetailView(entry: entry)
        }
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            List(model.filteredItems) { item in
                LogEntryRow(entry: item.entry)
                    .id(item.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedEntry = item.entry
                    }
            }
            .listStyle(.plain)
            .onChange(of: model.items.count) { _, _ in
                if model.searchText.isEmpty, let last = model.filteredItems.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
            .onAppear {
                if let last = model.filteredItems.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}

private struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                LevelBadge(level: entry.level)
                Text(entry.label)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Text(entry.timestamp.prefix(19).replacingOccurrences(of: "T", with: " "))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(entry.message)
                .font(.subheadline)
                .lineLimit(3)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 2)
    }
}

private struct LogEntryDetailView: View {
    let entry: LogEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LabeledContent("Level") {
                        LevelBadge(level: entry.level)
                    }
                    LabeledContent("Label") {
                        Text(entry.label)
                            .font(.body.monospaced())
                    }
                    LabeledContent("Time") {
                        Text(entry.timestamp.replacingOccurrences(of: "T", with: " "))
                            .font(.body.monospaced())
                    }
                    if let source = entry.source {
                        LabeledContent("Source") {
                            Text(source)
                                .font(.body.monospaced())
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Message")
                            .font(.headline)
                        Text(entry.message)
                            .font(.body)
                            .textSelection(.enabled)
                    }

                    if let metadata = entry.metadata, !metadata.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Metadata")
                                .font(.headline)
                            ForEach(metadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                LabeledContent(key) {
                                    Text(value)
                                        .font(.body.monospaced())
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Log Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct LevelBadge: View {
    let level: String

    var body: some View {
        Text(level.uppercased())
            .font(.caption2.bold())
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.15))
            .foregroundStyle(badgeColor)
            .clipShape(.rect(cornerRadius: 4))
    }

    private var badgeColor: Color {
        switch level {
        case "critical", "error": return .red
        case "warning": return .orange
        case "notice", "info": return .green
        case "debug": return .blue
        case "trace": return .secondary
        default: return .primary
        }
    }
}
