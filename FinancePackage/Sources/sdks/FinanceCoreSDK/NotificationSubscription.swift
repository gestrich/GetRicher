import Foundation

public enum DayOfWeek: String, Sendable, Codable, CaseIterable {
    case MON, TUE, WED, THU, FRI, SAT, SUN

    public static let everyDay: [DayOfWeek] = allCases
    public static let weekdays: [DayOfWeek] = [.MON, .TUE, .WED, .THU, .FRI]

    /// Maps `Calendar.component(.weekday, from:)` (1=Sun..7=Sat) to a DayOfWeek.
    public static func from(calendarWeekday: Int) -> DayOfWeek? {
        switch calendarWeekday {
        case 1: return .SUN
        case 2: return .MON
        case 3: return .TUE
        case 4: return .WED
        case 5: return .THU
        case 6: return .FRI
        case 7: return .SAT
        default: return nil
        }
    }
}

public struct NotificationSubscription: Sendable, Codable, Identifiable, Equatable {
    public let userId: String
    public let accountId: Int
    public var daysOfWeek: [DayOfWeek]
    public var hour: Int
    public var timezone: String
    public var enabled: Bool
    public var lastSentLocalDate: String?
    public let createdAt: String
    public var updatedAt: String

    public var id: String { "\(userId)#\(accountId)" }

    public init(
        userId: String,
        accountId: Int,
        daysOfWeek: [DayOfWeek],
        hour: Int,
        timezone: String,
        enabled: Bool = true,
        lastSentLocalDate: String? = nil,
        createdAt: String,
        updatedAt: String
    ) {
        self.userId = userId
        self.accountId = accountId
        self.daysOfWeek = daysOfWeek
        self.hour = hour
        self.timezone = timezone
        self.enabled = enabled
        self.lastSentLocalDate = lastSentLocalDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Server-side write shape — clients (iOS, CLI) send this to upsert a subscription.
/// Server fills in `userId`, `createdAt`, `updatedAt`, and preserves `lastSentLocalDate`
/// from any existing record.
public struct NotificationSubscriptionWrite: Sendable, Codable, Equatable {
    public let accountId: Int
    public let daysOfWeek: [DayOfWeek]
    public let hour: Int
    public let timezone: String
    public let enabled: Bool

    public init(accountId: Int, daysOfWeek: [DayOfWeek], hour: Int, timezone: String, enabled: Bool = true) {
        self.accountId = accountId
        self.daysOfWeek = daysOfWeek
        self.hour = hour
        self.timezone = timezone
        self.enabled = enabled
    }
}
