//
//  PlaidAccount.swift
//  Finance
//
//  Created by Bill Gestrich on 1/14/26.
//

import Foundation

struct PlaidAccount: Codable, Identifiable {
    let id: Int
    let name: String
    let displayName: String
    let type: String
    let subtype: String
    let mask: String
    let institutionName: String
    let status: String
    let balance: String
    let currency: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case displayName = "display_name"
        case type
        case subtype
        case mask
        case institutionName = "institution_name"
        case status
        case balance
        case currency
    }
}

struct PlaidAccountsResponse: Codable {
    let plaidAccounts: [PlaidAccount]

    enum CodingKeys: String, CodingKey {
        case plaidAccounts = "plaid_accounts"
    }
}
