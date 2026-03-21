import Charts
import CoreService
import PersistenceService
import SwiftData
import SwiftUI

struct WeeklyPaydownView: View {
    @Environment(TransactionsModel.self) var transactionsModel
    @Environment(\.modelContext) var modelContext
    @Query(sort: \PersistenceService.Transaction.date, order: .reverse) var transactions: [PersistenceService.Transaction]
    @Query(sort: \PersistenceService.PlaidAccount.displayName) var accounts: [PersistenceService.PlaidAccount]
    @State private var selectedAccountId: Int? = nil
    @State private var pivotDay: PivotDay = .saturday
    @State private var showSettings = false

    private var selectedAccount: PersistenceService.PlaidAccount? {
        guard let accountId = selectedAccountId else { return nil }
        return accounts.first { $0.lunchMoneyId == accountId }
    }

    private var dateRange: (start: String, end: String) {
        let calendar = Calendar.current
        let now = Date()

        // Find most recent pivot day at midnight
        let targetWeekday = pivotDay.weekdayNumber
        var end = now
        while calendar.component(.weekday, from: end) != targetWeekday {
            end = calendar.date(byAdding: .day, value: -1, to: end)!
        }
        end = calendar.startOfDay(for: end)

        // If today IS the pivot day, use today as end
        // Period start is 7 days before end
        let start = calendar.date(byAdding: .day, value: -7, to: end)!

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return (formatter.string(from: start), formatter.string(from: end))
    }

    private var periodTransactions: [PersistenceService.Transaction] {
        let range = dateRange
        return transactions.filter { tx in
            let accountMatch = selectedAccountId == nil || tx.plaidAccountId == selectedAccountId
            let dateMatch = tx.date > range.start && tx.date <= range.end
            return accountMatch && dateMatch && !tx.isIncome
        }
    }

    private var postPeriodClearedTransactions: [PersistenceService.Transaction] {
        let range = dateRange
        return transactions.filter { tx in
            let accountMatch = selectedAccountId == nil || tx.plaidAccountId == selectedAccountId
            let isAfterPeriod = tx.date > range.end
            let isCleared = tx.status.lowercased() == "cleared"
            return accountMatch && isAfterPeriod && isCleared && !tx.isIncome
        }
    }

    private var pendingInPeriod: [PersistenceService.Transaction] {
        periodTransactions.filter { $0.isPending }
    }

    private var calculation: PaydownCalculation {
        let balance = selectedAccount.flatMap { Double($0.balance) } ?? 0.0
        let pendingTotal = pendingInPeriod.reduce(0.0) { $0 + abs($1.toBase) }
        let postPeriodTotal = postPeriodClearedTransactions.reduce(0.0) { $0 + abs($1.toBase) }
        let adjusted = balance + pendingTotal - postPeriodTotal
        return PaydownCalculation(
            currentBalance: balance,
            pendingAdjustment: pendingTotal,
            postPeriodAdjustment: postPeriodTotal,
            adjustedSpending: adjusted
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if transactionsModel.isSyncing && transactions.isEmpty {
                    ProgressView("Loading...")
                } else if accounts.isEmpty {
                    ContentUnavailableView(
                        "No Accounts",
                        systemImage: "creditcard",
                        description: Text("No accounts available. Sync data first.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            accountPicker
                            periodHeader
                            if selectedAccount != nil {
                                calculationBreakdown
                                vendorChart
                                transactionList
                            } else {
                                ContentUnavailableView(
                                    "Select an Account",
                                    systemImage: "creditcard",
                                    description: Text("Choose a credit card account to see the weekly paydown amount.")
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Weekly Paydown")
            .task {
                let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
                transactionsModel.sync(
                    context: modelContext,
                    accountId: nil,
                    startDate: twoYearsAgo,
                    endDate: Date()
                )
            }
            .refreshable {
                let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
                transactionsModel.sync(
                    context: modelContext,
                    accountId: nil,
                    startDate: twoYearsAgo,
                    endDate: Date()
                )
            }
        }
    }

    private var accountPicker: some View {
        VStack(spacing: 12) {
            Picker("Account", selection: $selectedAccountId) {
                Text("Select Account").tag(nil as Int?)
                ForEach(accounts) { account in
                    Text(account.displayName).tag(account.lunchMoneyId as Int?)
                }
            }
            .pickerStyle(.menu)

            Picker("Pivot Day", selection: $pivotDay) {
                ForEach(PivotDay.allCases, id: \.self) { day in
                    Text(day.rawValue).tag(day)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(.horizontal)
    }

    private var periodHeader: some View {
        let range = dateRange
        return VStack(spacing: 4) {
            Text("7-Day Period")
                .font(.headline)
            Text("\(range.start) → \(range.end)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private var calculationBreakdown: some View {
        let calc = calculation
        return VStack(spacing: 0) {
            Text("Paydown Calculation")
                .font(.headline)
                .padding(.bottom, 12)

            CalculationRow(
                label: "Current Balance",
                amount: calc.currentBalance,
                explanation: "The balance reported by your bank right now. This reflects all cleared transactions but not pending ones.",
                isTotal: false,
                sign: ""
            )

            CalculationRow(
                label: "Pending in Period",
                amount: calc.pendingAdjustment,
                explanation: "Transactions within the 7-day period that haven't cleared yet. These are real charges that your balance doesn't include, so we add them.",
                isTotal: false,
                sign: "+"
            )

            CalculationRow(
                label: "Cleared After Period",
                amount: calc.postPeriodAdjustment,
                explanation: "Transactions that cleared AFTER the 7-day window. They're already in your balance but belong to next week, so we subtract them.",
                isTotal: false,
                sign: "−"
            )

            Divider()
                .padding(.vertical, 8)

            CalculationRow(
                label: "Amount to Pay",
                amount: calc.adjustedSpending,
                explanation: "This is how much to pay your credit card vendor for the 7-day period.",
                isTotal: true,
                sign: "="
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("PaydownCalculation")
    }

    private var vendorChart: some View {
        let vendorSpending = VendorSpending.aggregate(from: periodTransactions)
        let topVendors = Array(vendorSpending.prefix(8))

        return Group {
            if !topVendors.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Top Vendors This Week")
                        .font(.headline)
                        .padding(.horizontal)

                    Chart(topVendors) { vendor in
                        BarMark(
                            x: .value("Amount", vendor.totalAmount),
                            y: .value("Vendor", vendor.vendor)
                        )
                        .foregroundStyle(by: .value("Vendor", vendor.vendor))
                        .annotation(position: .trailing) {
                            Text(CurrencyFormatter.format(amount: vendor.totalAmount, currency: "USD"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: CGFloat(topVendors.count * 44))
                    .padding()
                    .chartLegend(.hidden)
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    private var transactionList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transactions (\(periodTransactions.count))")
                .font(.headline)
                .padding(.horizontal)

            if periodTransactions.isEmpty {
                Text("No transactions in this period.")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(periodTransactions) { transaction in
                    NavigationLink {
                        TransactionDetailView(transaction: transaction)
                    } label: {
                        TransactionRow(transaction: transaction)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
    }
}

struct CalculationRow: View {
    let label: String
    let amount: Double
    let explanation: String
    let isTotal: Bool
    let sign: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if !sign.isEmpty {
                    Text(sign)
                        .font(isTotal ? .title2.bold() : .body)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }
                Text(label)
                    .font(isTotal ? .title2.bold() : .body)
                Spacer()
                Text(CurrencyFormatter.format(amount: amount, currency: "USD"))
                    .font(isTotal ? .title2.bold() : .body.monospacedDigit())
                    .foregroundStyle(isTotal ? .green : .primary)
            }
            Text(explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
    }
}

enum PivotDay: String, CaseIterable {
    case sunday = "Sunday"
    case monday = "Monday"
    case tuesday = "Tuesday"
    case wednesday = "Wednesday"
    case thursday = "Thursday"
    case friday = "Friday"
    case saturday = "Saturday"

    var weekdayNumber: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }
}

struct PaydownCalculation {
    let currentBalance: Double
    let pendingAdjustment: Double
    let postPeriodAdjustment: Double
    let adjustedSpending: Double
}
