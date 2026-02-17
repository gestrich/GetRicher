import CoreService
import Foundation
import KeychainSDK
import LunchMoneySDK
import TransactionFeature

@MainActor @Observable
class TransactionsModel {
    var state: State = .idle

    private let fetchTransactionsUseCase: FetchTransactionsUseCase
    private let pageSize: Int

    init(lunchMoneyClient: any LunchMoneyClientProtocol, keychainClient: any KeychainClientProtocol, pageSize: Int) {
        self.pageSize = pageSize
        self.fetchTransactionsUseCase = FetchTransactionsUseCase(
            lunchMoneyClient: lunchMoneyClient,
            keychainClient: keychainClient,
            pageSize: pageSize
        )
    }

    func fetchTransactions(accountId: Int?, startDate: Date, endDate: Date) {
        state = .loading
        Task {
            do {
                let result = try await fetchTransactionsUseCase.run(options: .init(
                    accountId: accountId,
                    startDate: startDate,
                    endDate: endDate,
                    existingTransactions: [],
                    offset: 0
                ))
                state = .loaded(transactions: result.transactions, hasMore: result.hasMore)
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    func loadMore(accountId: Int?, startDate: Date, endDate: Date) {
        guard case .loaded(let transactions, let hasMore) = state, hasMore else { return }
        state = .loadingMore(transactions: transactions)
        Task {
            do {
                let result = try await fetchTransactionsUseCase.run(options: .init(
                    accountId: accountId,
                    startDate: startDate,
                    endDate: endDate,
                    existingTransactions: transactions,
                    offset: transactions.count
                ))
                state = .loaded(transactions: result.transactions, hasMore: result.hasMore)
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    var transactions: [Transaction] {
        switch state {
        case .idle, .loading, .error: return []
        case .loaded(let transactions, _): return transactions
        case .loadingMore(let transactions): return transactions
        }
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var isLoadingMore: Bool {
        if case .loadingMore = state { return true }
        return false
    }

    var hasMore: Bool {
        switch state {
        case .loaded(_, let hasMore): return hasMore
        case .loadingMore: return true
        default: return false
        }
    }

    var errorMessage: String? {
        if case .error(let message) = state { return message }
        return nil
    }

    enum State {
        case idle
        case loading
        case loaded(transactions: [Transaction], hasMore: Bool)
        case loadingMore(transactions: [Transaction])
        case error(String)
    }
}
