import Foundation

public struct VendorSpending: Identifiable, Sendable {
    public let id: UUID
    public let vendor: String
    public let totalAmount: Double
    public let transactionCount: Int

    public init(vendor: String, totalAmount: Double, transactionCount: Int) {
        self.id = UUID()
        self.vendor = vendor
        self.totalAmount = totalAmount
        self.transactionCount = transactionCount
    }

    public static func aggregate(from transactions: [Transaction]) -> [VendorSpending] {
        var vendorTotals: [String: (total: Double, count: Int)] = [:]

        for transaction in transactions {
            guard !transaction.isIncome else { continue }

            let vendor = transaction.payee
            let amount = abs(transaction.toBase)

            if let existing = vendorTotals[vendor] {
                vendorTotals[vendor] = (existing.total + amount, existing.count + 1)
            } else {
                vendorTotals[vendor] = (amount, 1)
            }
        }

        return vendorTotals.map { vendor, data in
            VendorSpending(vendor: vendor, totalAmount: data.total, transactionCount: data.count)
        }
        .sorted { $0.totalAmount > $1.totalAmount }
    }
}
