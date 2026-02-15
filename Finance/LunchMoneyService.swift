//
//  LunchMoneyService.swift
//  Finance
//
//  Created by Bill Gestrich on 1/14/26.
//

import Foundation

@Observable
@MainActor
class LunchMoneyService {
    var transactions: [Transaction] = []
    var plaidAccounts: [PlaidAccount] = []
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?
    var hasMore = true

    private var apiToken: String? {
        KeychainService.shared.getAPIToken()
    }
    private let baseURL = "https://dev.lunchmoney.app/v1"
    private let pageSize = 200
    private var offset = 0

    func fetchTransactions(accountId: Int? = nil, startDate: Date? = nil, endDate: Date? = nil) async {
        isLoading = true
        errorMessage = nil
        offset = 0
        transactions = []

        await loadTransactions(accountId: accountId, startDate: startDate, endDate: endDate)
        isLoading = false
    }

    func loadMoreTransactions(accountId: Int? = nil, startDate: Date? = nil, endDate: Date? = nil) async {
        guard !isLoadingMore && hasMore else { return }
        isLoadingMore = true
        offset += pageSize
        await loadTransactions(accountId: accountId, startDate: startDate, endDate: endDate)
        isLoadingMore = false
    }

    private func loadTransactions(accountId: Int? = nil, startDate: Date? = nil, endDate: Date? = nil) async {
        guard let token = apiToken else {
            errorMessage = "API token not configured. Please add your token in Settings."
            return
        }

        let calendar = Calendar.current
        let finalEndDate = endDate ?? Date()
        let finalStartDate = startDate ?? calendar.date(byAdding: .year, value: -2, to: finalEndDate)!

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var urlComponents = URLComponents(string: "\(baseURL)/transactions")
        var queryItems = [
            URLQueryItem(name: "start_date", value: dateFormatter.string(from: finalStartDate)),
            URLQueryItem(name: "end_date", value: dateFormatter.string(from: finalEndDate)),
            URLQueryItem(name: "limit", value: "\(pageSize)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]

        if let accountId = accountId {
            queryItems.append(URLQueryItem(name: "plaid_account_id", value: "\(accountId)"))
        }

        urlComponents?.queryItems = queryItems

        guard let url = urlComponents?.url else {
            errorMessage = "Invalid URL"
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Invalid response"
                return
            }

            guard httpResponse.statusCode == 200 else {
                errorMessage = "Server error: \(httpResponse.statusCode)"
                return
            }

            let decoder = JSONDecoder()
            let transactionsResponse = try decoder.decode(TransactionsResponse.self, from: data)

            let newTransactions = transactionsResponse.transactions
            hasMore = newTransactions.count == pageSize

            transactions.append(contentsOf: newTransactions)
            transactions.sort { $0.date > $1.date }
        } catch {
            errorMessage = "Failed to fetch transactions: \(error.localizedDescription)"
        }
    }

    func fetchPlaidAccounts() async {
        guard let token = apiToken else {
            return
        }

        guard let url = URL(string: "\(baseURL)/plaid_accounts") else {
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return
            }

            let decoder = JSONDecoder()
            let accountsResponse = try decoder.decode(PlaidAccountsResponse.self, from: data)
            plaidAccounts = accountsResponse.plaidAccounts.sorted { $0.displayName < $1.displayName }
        } catch {
            // Silently fail for accounts - not critical
        }
    }
}
