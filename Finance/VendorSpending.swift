//
//  VendorSpending.swift
//  Finance
//
//  Created by Bill Gestrich on 1/14/26.
//

import Foundation

struct VendorSpending: Identifiable {
    let id = UUID()
    let vendor: String
    let totalAmount: Double
    let transactionCount: Int

    static func aggregate(from transactions: [Transaction]) -> [VendorSpending] {
        var vendorTotals: [String: (total: Double, count: Int)] = [:]

        for transaction in transactions {
            // Skip income transactions
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
