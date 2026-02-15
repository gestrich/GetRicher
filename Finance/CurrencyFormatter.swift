//
//  CurrencyFormatter.swift
//  Finance
//
//  Created by Bill Gestrich on 1/14/26.
//

import Foundation

struct CurrencyFormatter {
    static func format(amount: String, currency: String) -> String {
        guard let doubleAmount = Double(amount) else {
            return "\(currency.uppercased()) \(amount)"
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.uppercased()

        return formatter.string(from: NSNumber(value: doubleAmount)) ?? "\(currency.uppercased()) \(amount)"
    }

    static func format(amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.uppercased()

        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency.uppercased()) \(String(format: "%.2f", amount))"
    }
}
