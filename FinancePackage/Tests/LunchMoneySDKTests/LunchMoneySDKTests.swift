import Testing
@testable import LunchMoneySDK
import Foundation

// MARK: - Helpers

private let minimalTransactionJSON = """
{
    "id": 42,
    "date": "2026-05-01",
    "payee": "Whole Foods",
    "amount": "87.50",
    "currency": "usd",
    "to_base": 87.5,
    "original_name": "WHOLEFDS",
    "status": "cleared",
    "is_income": false,
    "is_pending": false,
    "exclude_from_budget": false,
    "exclude_from_totals": false,
    "created_at": "2026-05-01T10:00:00Z",
    "updated_at": "2026-05-01T10:00:00Z",
    "has_children": false,
    "is_group": false
}
"""

// MARK: - TransactionDTO

@Suite struct TransactionDTODecodingTests {
    @Test("decodes required fields from minimal JSON")
    func decodeRequiredFields() throws {
        let data = try #require(minimalTransactionJSON.data(using: .utf8))
        let dto = try JSONDecoder().decode(TransactionDTO.self, from: data)

        #expect(dto.id == 42)
        #expect(dto.date == "2026-05-01")
        #expect(dto.payee == "Whole Foods")
        #expect(dto.amount == "87.50")
        #expect(dto.toBase == 87.5)
        #expect(dto.originalName == "WHOLEFDS")
        #expect(dto.status == "cleared")
        #expect(dto.isIncome == false)
        #expect(dto.isPending == false)
        #expect(dto.excludeFromBudget == false)
        #expect(dto.excludeFromTotals == false)
    }

    @Test("optional fields decode as nil when absent")
    func decodeAbsentOptionalsAreNil() throws {
        let data = try #require(minimalTransactionJSON.data(using: .utf8))
        let dto = try JSONDecoder().decode(TransactionDTO.self, from: data)

        #expect(dto.notes == nil)
        #expect(dto.categoryId == nil)
        #expect(dto.categoryName == nil)
        #expect(dto.tags == nil)
        #expect(dto.recurringId == nil)
        #expect(dto.plaidAccountId == nil)
    }

    @Test("decodes tags array when present")
    func decodeWithTags() throws {
        let json = """
        {
            "id": 1, "date": "2026-05-01", "payee": "Target",
            "amount": "50.00", "currency": "usd", "to_base": 50.0,
            "original_name": "TARGET", "status": "cleared",
            "is_income": false, "is_pending": false,
            "exclude_from_budget": false, "exclude_from_totals": false,
            "created_at": "2026-05-01", "updated_at": "2026-05-01",
            "has_children": false, "is_group": false,
            "tags": [{"id": 7, "name": "groceries"}]
        }
        """
        let data = try #require(json.data(using: .utf8))
        let dto = try JSONDecoder().decode(TransactionDTO.self, from: data)

        #expect(dto.tags?.count == 1)
        #expect(dto.tags?.first?.id == 7)
        #expect(dto.tags?.first?.name == "groceries")
    }

    @Test("decodes snake_case category fields")
    func decodeSnakeCaseCategoryFields() throws {
        let json = """
        {
            "id": 5, "date": "2026-05-01", "payee": "Trader Joe's",
            "amount": "120.00", "currency": "usd", "to_base": 120.0,
            "original_name": "TRADER JOES", "status": "cleared",
            "is_income": false, "is_pending": false,
            "exclude_from_budget": false, "exclude_from_totals": false,
            "created_at": "2026-05-01", "updated_at": "2026-05-01",
            "has_children": false, "is_group": false,
            "category_id": 3,
            "category_name": "Groceries",
            "category_group_id": 1,
            "category_group_name": "Food"
        }
        """
        let data = try #require(json.data(using: .utf8))
        let dto = try JSONDecoder().decode(TransactionDTO.self, from: data)

        #expect(dto.categoryId == 3)
        #expect(dto.categoryName == "Groceries")
        #expect(dto.categoryGroupId == 1)
        #expect(dto.categoryGroupName == "Food")
    }
}

// MARK: - TransactionsResponseDTO

@Suite struct TransactionsResponseDTODecodingTests {
    @Test("decodes transactions array from response wrapper")
    func decodeTransactionsArray() throws {
        let json = """
        {
            "transactions": [
                {
                    "id": 1, "date": "2026-05-01", "payee": "Starbucks",
                    "amount": "6.00", "currency": "usd", "to_base": 6.0,
                    "original_name": "STARBUCKS", "status": "cleared",
                    "is_income": false, "is_pending": false,
                    "exclude_from_budget": false, "exclude_from_totals": false,
                    "created_at": "2026-05-01", "updated_at": "2026-05-01",
                    "has_children": false, "is_group": false
                },
                {
                    "id": 2, "date": "2026-05-02", "payee": "Amazon",
                    "amount": "35.00", "currency": "usd", "to_base": 35.0,
                    "original_name": "AMAZON", "status": "cleared",
                    "is_income": false, "is_pending": false,
                    "exclude_from_budget": false, "exclude_from_totals": false,
                    "created_at": "2026-05-02", "updated_at": "2026-05-02",
                    "has_children": false, "is_group": false
                }
            ]
        }
        """
        let data = try #require(json.data(using: .utf8))
        let response = try JSONDecoder().decode(TransactionsResponseDTO.self, from: data)

        #expect(response.transactions.count == 2)
        #expect(response.transactions[0].payee == "Starbucks")
        #expect(response.transactions[1].id == 2)
    }

    @Test("decodes empty transactions array")
    func decodeEmptyTransactions() throws {
        let json = #"{"transactions": []}"#
        let data = try #require(json.data(using: .utf8))
        let response = try JSONDecoder().decode(TransactionsResponseDTO.self, from: data)
        #expect(response.transactions.isEmpty)
    }
}

// MARK: - PlaidAccountDTO

@Suite struct PlaidAccountDTODecodingTests {
    private let accountJSON = """
    {
        "id": 123,
        "name": "Amex Gold",
        "display_name": "Amex Gold Card",
        "type": "credit",
        "subtype": "credit_card",
        "mask": "9876",
        "institution_name": "American Express",
        "status": "active",
        "balance": "1250.00",
        "currency": "usd"
    }
    """

    @Test("decodes all fields including snake_case keys")
    func decodeAllFields() throws {
        let data = try #require(accountJSON.data(using: .utf8))
        let dto = try JSONDecoder().decode(PlaidAccountDTO.self, from: data)

        #expect(dto.id == 123)
        #expect(dto.name == "Amex Gold")
        #expect(dto.displayName == "Amex Gold Card")
        #expect(dto.type == "credit")
        #expect(dto.subtype == "credit_card")
        #expect(dto.mask == "9876")
        #expect(dto.institutionName == "American Express")
        #expect(dto.status == "active")
        #expect(dto.balance == "1250.00")
        #expect(dto.currency == "usd")
    }
}

// MARK: - PlaidAccountsResponseDTO

@Suite struct PlaidAccountsResponseDTODecodingTests {
    @Test("decodes plaid_accounts key from response wrapper")
    func decodePlaidAccountsKey() throws {
        let json = """
        {
            "plaid_accounts": [
                {
                    "id": 1, "name": "Chase", "display_name": "Chase Checking",
                    "type": "depository", "subtype": "checking", "mask": "1111",
                    "institution_name": "Chase", "status": "active",
                    "balance": "2000.00", "currency": "usd"
                }
            ]
        }
        """
        let data = try #require(json.data(using: .utf8))
        let response = try JSONDecoder().decode(PlaidAccountsResponseDTO.self, from: data)

        #expect(response.plaidAccounts.count == 1)
        #expect(response.plaidAccounts[0].name == "Chase")
        #expect(response.plaidAccounts[0].displayName == "Chase Checking")
    }

    @Test("decodes empty plaid_accounts array")
    func decodeEmptyPlaidAccounts() throws {
        let json = #"{"plaid_accounts": []}"#
        let data = try #require(json.data(using: .utf8))
        let response = try JSONDecoder().decode(PlaidAccountsResponseDTO.self, from: data)
        #expect(response.plaidAccounts.isEmpty)
    }
}

// MARK: - TagDTO

@Suite struct TagDTODecodingTests {
    @Test("decodes id and name fields")
    func decodeTagFields() throws {
        let json = #"{"id": 5, "name": "travel"}"#
        let data = try #require(json.data(using: .utf8))
        let tag = try JSONDecoder().decode(TagDTO.self, from: data)

        #expect(tag.id == 5)
        #expect(tag.name == "travel")
    }

    @Test("decodes tag with null fields")
    func decodeTagWithNullFields() throws {
        let json = #"{"id": null, "name": null}"#
        let data = try #require(json.data(using: .utf8))
        let tag = try JSONDecoder().decode(TagDTO.self, from: data)

        #expect(tag.id == nil)
        #expect(tag.name == nil)
    }
}
