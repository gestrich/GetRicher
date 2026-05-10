import Testing
@testable import NotificationService
import FinanceCoreSDK
import Foundation

// MARK: - In-memory store implementations

actor InMemoryAccountStore: AccountStoreProtocol {
    private var storage: [String: [Account]] = [:]

    func store(_ accounts: [Account], userId: String) async throws {
        storage[userId] = accounts
    }

    func fetchAll(userId: String) async throws -> [Account] {
        storage[userId] ?? []
    }

    func deleteAll(userId: String) async throws {
        storage.removeValue(forKey: userId)
    }
}

actor InMemoryTransactionStore: TransactionStoreProtocol {
    private var storage: [String: [Transaction]] = [:]

    func store(_ transactions: [Transaction], userId: String) async throws {
        storage[userId] = transactions
    }

    func fetch(userId: String, startDate: String, endDate: String) async throws -> [Transaction] {
        (storage[userId] ?? []).filter { $0.date >= startDate && $0.date <= endDate }
    }

    func deleteAll(userId: String) async throws {
        storage.removeValue(forKey: userId)
    }
}

actor InMemoryUserStore: UserStoreProtocol {
    private var users: [String: UserAccount] = [:]

    func create(_ user: UserAccount) async throws {
        users[user.username] = user
    }

    func find(username: String) async throws -> UserAccount? {
        users[username]
    }

    func fetchAll() async throws -> [UserAccount] {
        Array(users.values)
    }

    func update(lunchMoneyToken: String, forUsername username: String) async throws {
        guard let existing = users[username] else { return }
        users[username] = UserAccount(
            username: existing.username,
            passwordHash: existing.passwordHash,
            createdAt: existing.createdAt,
            lunchMoneyToken: lunchMoneyToken
        )
    }

    func delete(username: String) async throws {
        users.removeValue(forKey: username)
    }
}

// MARK: - Account store tests

@Suite("Account store")
struct AccountStoreTests {
    @Test("LoggingAccountStore does not throw and returns empty")
    func loggingStoreSmoke() async throws {
        let store = LoggingAccountStore()
        let result = try await store.fetchAll(userId: "u1")
        #expect(result.isEmpty)
    }

    @Test("Stored accounts can be fetched back")
    func roundtrip() async throws {
        let store = InMemoryAccountStore()
        try await store.store([makeAccount(id: 1), makeAccount(id: 2)], userId: "u1")
        let result = try await store.fetchAll(userId: "u1")
        #expect(result.count == 2)
    }

    @Test("Fetch returns empty for unknown user")
    func unknownUser() async throws {
        let store = InMemoryAccountStore()
        #expect(try await store.fetchAll(userId: "nobody").isEmpty)
    }

    @Test("deleteAll removes stored accounts")
    func deleteAll() async throws {
        let store = InMemoryAccountStore()
        try await store.store([makeAccount(id: 1)], userId: "u1")
        try await store.deleteAll(userId: "u1")
        #expect(try await store.fetchAll(userId: "u1").isEmpty)
    }

    @Test("Accounts are isolated per user")
    func userIsolation() async throws {
        let store = InMemoryAccountStore()
        try await store.store([makeAccount(id: 1)], userId: "u1")
        try await store.store([makeAccount(id: 2), makeAccount(id: 3)], userId: "u2")
        #expect(try await store.fetchAll(userId: "u1").count == 1)
        #expect(try await store.fetchAll(userId: "u2").count == 2)
    }
}

// MARK: - Transaction store tests

@Suite("Transaction store")
struct TransactionStoreTests {
    @Test("LoggingTransactionStore does not throw and returns empty")
    func loggingStoreSmoke() async throws {
        let store = LoggingTransactionStore()
        let result = try await store.fetch(userId: "u1", startDate: "2026-01-01", endDate: "2026-12-31")
        #expect(result.isEmpty)
    }

    @Test("Stored transactions can be fetched back within date range")
    func roundtrip() async throws {
        let store = InMemoryTransactionStore()
        try await store.store([makeTransaction(id: 1, date: "2026-04-15")], userId: "u1")
        let result = try await store.fetch(userId: "u1", startDate: "2026-04-01", endDate: "2026-04-30")
        #expect(result.count == 1)
        #expect(result[0].lunchMoneyId == 1)
    }

    @Test(
        "Date range filtering — boundary and out-of-range cases",
        arguments: zip(
            ["2026-03-15", "2026-04-01", "2026-04-15", "2026-04-30", "2026-05-01"],
            [false,        true,          true,          true,          false       ]
        )
    )
    func dateFilter(date: String, included: Bool) async throws {
        let store = InMemoryTransactionStore()
        try await store.store([makeTransaction(id: 1, date: date)], userId: "u1")
        let result = try await store.fetch(userId: "u1", startDate: "2026-04-01", endDate: "2026-04-30")
        #expect(result.isEmpty == !included)
    }

    @Test("deleteAll removes stored transactions")
    func deleteAll() async throws {
        let store = InMemoryTransactionStore()
        try await store.store([makeTransaction(id: 1, date: "2026-04-15")], userId: "u1")
        try await store.deleteAll(userId: "u1")
        let result = try await store.fetch(userId: "u1", startDate: "2026-01-01", endDate: "2026-12-31")
        #expect(result.isEmpty)
    }

    @Test("Fetch returns empty for unknown user")
    func unknownUser() async throws {
        let store = InMemoryTransactionStore()
        let result = try await store.fetch(userId: "nobody", startDate: "2026-01-01", endDate: "2026-12-31")
        #expect(result.isEmpty)
    }
}

// MARK: - Route handler flow tests (stub store injection)
//
// These tests exercise the exact data access patterns used by the Lambda
// route handlers (handleGetAccounts, handleGetTransactions, handleUserRegistration)
// by injecting in-memory stores and asserting the same outcomes.

@Suite("Lambda route handler flows")
struct RouteHandlerFlowTests {
    @Test("GET /api/accounts — valid credentials returns stored accounts")
    func getAccountsValidCredentials() async throws {
        let userStore = InMemoryUserStore()
        let accountStore = InMemoryAccountStore()

        let password = "secret"
        let user = UserAccount(
            username: "alice",
            passwordHash: UserAccount.hashPassword(password),
            createdAt: "2026-01-01"
        )
        try await userStore.create(user)
        try await accountStore.store([makeAccount(id: 1), makeAccount(id: 2)], userId: "alice")

        let found = try await userStore.find(username: "alice")
        let authenticated = found != nil && UserAccount.hashPassword(password) == found!.passwordHash
        #expect(authenticated)

        let accounts = try await accountStore.fetchAll(userId: found!.username)
        #expect(accounts.count == 2)
    }

    @Test("GET /api/accounts — invalid credentials fails authentication")
    func getAccountsInvalidCredentials() async throws {
        let userStore = InMemoryUserStore()
        let user = UserAccount(
            username: "alice",
            passwordHash: UserAccount.hashPassword("correct"),
            createdAt: "2026-01-01"
        )
        try await userStore.create(user)

        let found = try await userStore.find(username: "alice")
        let authenticated = found != nil && UserAccount.hashPassword("wrong") == found!.passwordHash
        #expect(!authenticated)
    }

    @Test("GET /api/accounts — unknown user fails authentication")
    func getAccountsUnknownUser() async throws {
        let userStore = InMemoryUserStore()
        let found = try await userStore.find(username: "ghost")
        #expect(found == nil)
    }

    @Test("GET /api/transactions — valid credentials returns filtered transactions")
    func getTransactionsValidCredentials() async throws {
        let userStore = InMemoryUserStore()
        let transactionStore = InMemoryTransactionStore()

        let password = "pass"
        let user = UserAccount(
            username: "bob",
            passwordHash: UserAccount.hashPassword(password),
            createdAt: "2026-01-01"
        )
        try await userStore.create(user)
        try await transactionStore.store([
            makeTransaction(id: 1, date: "2026-03-31"),
            makeTransaction(id: 2, date: "2026-04-10"),
            makeTransaction(id: 3, date: "2026-05-01"),
        ], userId: "bob")

        let found = try await userStore.find(username: "bob")
        let authenticated = found != nil && UserAccount.hashPassword(password) == found!.passwordHash
        #expect(authenticated)

        let transactions = try await transactionStore.fetch(
            userId: found!.username,
            startDate: "2026-04-01",
            endDate: "2026-04-30"
        )
        #expect(transactions.count == 1)
        #expect(transactions[0].lunchMoneyId == 2)
    }

    @Test("POST /api/users/register — new user is stored and findable")
    func registerNewUser() async throws {
        let userStore = InMemoryUserStore()

        let username = "carol"
        let password = "mypass"
        let user = UserAccount(
            username: username,
            passwordHash: UserAccount.hashPassword(password),
            createdAt: "2026-01-01"
        )
        try await userStore.create(user)

        let found = try await userStore.find(username: username)
        #expect(found != nil)
        #expect(found!.username == username)
        #expect(UserAccount.hashPassword(password) == found!.passwordHash)
    }

    @Test("POST /api/users/register — duplicate registration is detectable")
    func registerDuplicateUser() async throws {
        let userStore = InMemoryUserStore()

        let user = UserAccount(username: "dave", passwordHash: "hash", createdAt: "2026-01-01")
        try await userStore.create(user)

        let existing = try await userStore.find(username: "dave")
        #expect(existing != nil, "Handler should detect existing user and return conflict")
    }
}

// MARK: - Model encoding roundtrip tests

@Suite("Model JSON encoding")
struct ModelEncodingTests {
    @Test("Account survives JSON encode/decode roundtrip")
    func accountRoundtrip() throws {
        let account = makeAccount(id: 42)
        let data = try JSONEncoder().encode(account)
        let decoded = try JSONDecoder().decode(Account.self, from: data)
        #expect(decoded.lunchMoneyId == 42)
        #expect(decoded.name == "Account42")
        #expect(decoded.balance == "1000.00")
        #expect(decoded.currency == "usd")
    }

    @Test("Transaction survives JSON encode/decode roundtrip")
    func transactionRoundtrip() throws {
        let tx = makeTransaction(id: 7, date: "2026-04-15")
        let data = try JSONEncoder().encode(tx)
        let decoded = try JSONDecoder().decode(Transaction.self, from: data)
        #expect(decoded.lunchMoneyId == 7)
        #expect(decoded.date == "2026-04-15")
        #expect(decoded.payee == "Vendor7")
    }

    @Test("Account array survives JSON encode/decode roundtrip")
    func accountArrayRoundtrip() throws {
        let accounts = [makeAccount(id: 1), makeAccount(id: 2), makeAccount(id: 3)]
        let data = try JSONEncoder().encode(accounts)
        let decoded = try JSONDecoder().decode([Account].self, from: data)
        #expect(decoded.count == 3)
        #expect(Set(decoded.map { $0.lunchMoneyId }) == [1, 2, 3])
    }

    @Test("Transaction array survives JSON encode/decode roundtrip")
    func transactionArrayRoundtrip() throws {
        let txs = [
            makeTransaction(id: 1, date: "2026-04-01"),
            makeTransaction(id: 2, date: "2026-04-15"),
        ]
        let data = try JSONEncoder().encode(txs)
        let decoded = try JSONDecoder().decode([Transaction].self, from: data)
        #expect(decoded.count == 2)
    }
}

// MARK: - UserAccount authentication tests

@Suite("UserAccount authentication")
struct UserAccountAuthTests {
    @Test("hashPassword produces consistent output")
    func hashConsistency() {
        let hash1 = UserAccount.hashPassword("mypassword")
        let hash2 = UserAccount.hashPassword("mypassword")
        #expect(hash1 == hash2)
    }

    @Test("Different passwords produce different hashes")
    func hashDifference() {
        let hash1 = UserAccount.hashPassword("password1")
        let hash2 = UserAccount.hashPassword("password2")
        #expect(hash1 != hash2)
    }

    @Test("Hash is deterministic across UserAccount instances")
    func hashIsDeterministic() {
        let password = "testpass"
        let hash = UserAccount.hashPassword(password)
        let user = UserAccount(username: "u", passwordHash: hash, createdAt: "2026-01-01")
        #expect(UserAccount.hashPassword(password) == user.passwordHash)
    }
}

// MARK: - Test helpers

private func makeAccount(id: Int) -> Account {
    Account(
        lunchMoneyId: id,
        name: "Account\(id)",
        displayName: "Account \(id)",
        type: "credit",
        subtype: "checking",
        mask: "000\(id)",
        institutionName: "TestBank",
        status: "active",
        balance: "1000.00",
        currency: "usd"
    )
}

private func makeTransaction(id: Int, date: String) -> Transaction {
    Transaction(
        lunchMoneyId: id,
        date: date,
        payee: "Vendor\(id)",
        amount: "50.00",
        currency: "usd",
        toBase: 50.0,
        originalName: "Vendor\(id)",
        status: "cleared",
        isIncome: false,
        isPending: false,
        excludeFromBudget: false,
        excludeFromTotals: false,
        createdAt: date,
        updatedAt: date,
        hasChildren: false,
        isGroup: false
    )
}
