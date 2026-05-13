import FinanceCoreSDK
import SwiftUI

struct EditSubscriptionView: View {
    @Environment(NotificationSubscriptionsModel.self) var model
    @Environment(\.dismiss) private var dismiss

    let account: Account
    let existing: NotificationSubscription?

    @State private var daysOfWeek: Set<DayOfWeek>
    @State private var hour: Int
    @State private var timezone: String
    @State private var enabled: Bool
    @State private var isSaving = false

    private static let timezoneOptions: [String] = {
        var options = [
            TimeZone.current.identifier,
            "UTC",
            "America/New_York",
            "America/Chicago",
            "America/Denver",
            "America/Los_Angeles",
        ]
        // Deduplicate while preserving order.
        var seen = Set<String>()
        return options.filter { seen.insert($0).inserted }
    }()

    init(account: Account, existing: NotificationSubscription?) {
        self.account = account
        self.existing = existing
        let initialDays = existing.map { Set($0.daysOfWeek) } ?? Set(DayOfWeek.allCases)
        _daysOfWeek = State(initialValue: initialDays)
        _hour = State(initialValue: existing?.hour ?? 9)
        _timezone = State(initialValue: existing?.timezone ?? TimeZone.current.identifier)
        _enabled = State(initialValue: existing?.enabled ?? true)
    }

    var body: some View {
        Form {
            Section("Days of the week") {
                Button("Every day") { daysOfWeek = Set(DayOfWeek.allCases) }
                Button("Weekdays") { daysOfWeek = Set(DayOfWeek.weekdays) }
                ForEach(DayOfWeek.allCases, id: \.self) { day in
                    Toggle(day.displayName, isOn: Binding(
                        get: { daysOfWeek.contains(day) },
                        set: { isOn in
                            if isOn { daysOfWeek.insert(day) } else { daysOfWeek.remove(day) }
                        }
                    ))
                }
            }

            Section("Hour") {
                Picker("Hour", selection: $hour) {
                    ForEach(0..<24) { h in
                        Text(formatHour(h)).tag(h)
                    }
                }
                .pickerStyle(.wheel)
            }

            Section("Timezone") {
                Picker("Timezone", selection: $timezone) {
                    ForEach(Self.timezoneOptions, id: \.self) { tz in
                        Text(tz).tag(tz)
                    }
                }
            }

            Section {
                Toggle("Enabled", isOn: $enabled)
            } footer: {
                Text("Disabled subscriptions are kept but never fire.")
            }

            if existing != nil {
                Section {
                    Button("Delete subscription", role: .destructive) {
                        Task {
                            isSaving = true
                            await model.delete(accountId: account.lunchMoneyId)
                            isSaving = false
                            dismiss()
                        }
                    }
                    .disabled(isSaving)
                }
            }

            if let msg = model.errorMessage {
                Section {
                    Text(msg).foregroundColor(.red).font(.footnote)
                }
            }
        }
        .navigationTitle(account.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        isSaving = true
                        await save()
                        isSaving = false
                        if model.errorMessage == nil { dismiss() }
                    }
                }
                .disabled(daysOfWeek.isEmpty || isSaving)
            }
        }
    }

    private func save() async {
        let write = NotificationSubscriptionWrite(
            accountId: account.lunchMoneyId,
            daysOfWeek: orderedDays(),
            hour: hour,
            timezone: timezone,
            enabled: enabled
        )
        await model.upsert(write)
    }

    private func orderedDays() -> [DayOfWeek] {
        DayOfWeek.allCases.filter { daysOfWeek.contains($0) }
    }
}

private extension DayOfWeek {
    var displayName: String {
        switch self {
        case .MON: return "Monday"
        case .TUE: return "Tuesday"
        case .WED: return "Wednesday"
        case .THU: return "Thursday"
        case .FRI: return "Friday"
        case .SAT: return "Saturday"
        case .SUN: return "Sunday"
        }
    }
}

private func formatHour(_ hour: Int) -> String {
    let suffix = hour < 12 ? "AM" : "PM"
    let h = hour % 12
    let display = h == 0 ? 12 : h
    return "\(display) \(suffix)"
}
