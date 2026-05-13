import Testing
@testable import NotificationService
import FinanceCoreSDK
import Foundation

@Suite("ScheduleEvaluator")
struct ScheduleEvaluatorTests {
    // 2026-05-12 is a Tuesday. Times below are UTC unless noted.
    private static func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso) ?? Date()
    }

    private static func sub(
        userId: String = "u",
        accountId: Int = 1,
        days: [DayOfWeek],
        hour: Int,
        timezone: String,
        enabled: Bool = true,
        lastSentLocalDate: String? = nil
    ) -> NotificationSubscription {
        NotificationSubscription(
            userId: userId,
            accountId: accountId,
            daysOfWeek: days,
            hour: hour,
            timezone: timezone,
            enabled: enabled,
            lastSentLocalDate: lastSentLocalDate,
            createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-01-01T00:00:00Z"
        )
    }

    @Test("Fires when day and hour match in the sub's timezone")
    func fires() {
        // 2026-05-12 13:00 UTC == 2026-05-12 09:00 America/New_York (EDT, UTC-4)
        let now = Self.date("2026-05-12T13:00:00Z")
        let s = Self.sub(days: [.TUE], hour: 9, timezone: "America/New_York")
        let fired = ScheduleEvaluator.fire(subs: [s], now: now)
        #expect(fired.count == 1)
        #expect(fired.first?.localDate == "2026-05-12")
    }

    @Test("Does not fire on a non-matching day of week")
    func wrongDay() {
        let now = Self.date("2026-05-12T13:00:00Z")  // Tuesday in NY
        let s = Self.sub(days: [.MON, .WED], hour: 9, timezone: "America/New_York")
        #expect(ScheduleEvaluator.fire(subs: [s], now: now).isEmpty)
    }

    @Test("Does not fire on a non-matching hour")
    func wrongHour() {
        let now = Self.date("2026-05-12T14:00:00Z")  // 10:00 NY
        let s = Self.sub(days: [.TUE], hour: 9, timezone: "America/New_York")
        #expect(ScheduleEvaluator.fire(subs: [s], now: now).isEmpty)
    }

    @Test("Does not fire when disabled")
    func disabled() {
        let now = Self.date("2026-05-12T13:00:00Z")
        let s = Self.sub(days: [.TUE], hour: 9, timezone: "America/New_York", enabled: false)
        #expect(ScheduleEvaluator.fire(subs: [s], now: now).isEmpty)
    }

    @Test("Does not fire when already sent today in the sub's local timezone")
    func dedupesSameLocalDate() {
        let now = Self.date("2026-05-12T13:00:00Z")
        let s = Self.sub(
            days: [.TUE],
            hour: 9,
            timezone: "America/New_York",
            lastSentLocalDate: "2026-05-12"
        )
        #expect(ScheduleEvaluator.fire(subs: [s], now: now).isEmpty)
    }

    @Test("Fires again on the next day after a previous send")
    func firesNextDay() {
        // 2026-05-13 13:00 UTC == 2026-05-13 09:00 NY (Wednesday)
        let now = Self.date("2026-05-13T13:00:00Z")
        let s = Self.sub(
            days: [.WED],
            hour: 9,
            timezone: "America/New_York",
            lastSentLocalDate: "2026-05-12"
        )
        let fired = ScheduleEvaluator.fire(subs: [s], now: now)
        #expect(fired.count == 1)
        #expect(fired.first?.localDate == "2026-05-13")
    }

    @Test("Timezone offset shifts which calendar day is 'today'")
    func timezoneShiftsLocalDay() {
        // 2026-05-13 02:00 UTC. In Los_Angeles (UTC-7 in May, PDT) that's still
        // 2026-05-12 19:00 — Tuesday, hour 19.
        let now = Self.date("2026-05-13T02:00:00Z")
        let s = Self.sub(days: [.TUE], hour: 19, timezone: "America/Los_Angeles")
        let fired = ScheduleEvaluator.fire(subs: [s], now: now)
        #expect(fired.count == 1)
        #expect(fired.first?.localDate == "2026-05-12")
    }

    @Test("Unknown timezone identifier never fires")
    func badTimezone() {
        let now = Self.date("2026-05-12T13:00:00Z")
        let s = Self.sub(days: DayOfWeek.everyDay, hour: 9, timezone: "Not/A_Real_TZ")
        #expect(ScheduleEvaluator.fire(subs: [s], now: now).isEmpty)
    }

    @Test("EVERY_DAY subscription fires on any matching hour")
    func everyDayFires() {
        let now = Self.date("2026-05-12T13:00:00Z")  // Tue 09:00 NY
        let s = Self.sub(days: DayOfWeek.everyDay, hour: 9, timezone: "America/New_York")
        #expect(ScheduleEvaluator.fire(subs: [s], now: now).count == 1)
    }

    @Test("Multiple subs are filtered independently")
    func multipleSubs() {
        let now = Self.date("2026-05-12T13:00:00Z")
        let firing = Self.sub(accountId: 1, days: [.TUE], hour: 9, timezone: "America/New_York")
        let wrongHour = Self.sub(accountId: 2, days: [.TUE], hour: 10, timezone: "America/New_York")
        let disabled = Self.sub(accountId: 3, days: [.TUE], hour: 9, timezone: "America/New_York", enabled: false)
        let fired = ScheduleEvaluator.fire(subs: [firing, wrongHour, disabled], now: now)
        #expect(fired.count == 1)
        #expect(fired.first?.subscription.accountId == 1)
    }
}
