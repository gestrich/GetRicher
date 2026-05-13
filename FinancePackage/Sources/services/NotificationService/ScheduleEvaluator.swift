import FinanceCoreSDK
import Foundation

/// Pure function — given a list of subscriptions and a moment in time, return the
/// subset that should fire right now. A subscription fires when, in its own
/// timezone: today's day-of-week is in `daysOfWeek`, the current hour matches
/// `hour`, the sub is `enabled`, and we haven't already sent for today's local
/// date (`lastSentLocalDate`).
public enum ScheduleEvaluator {
    public struct FiredSubscription: Sendable, Equatable {
        public let subscription: NotificationSubscription
        public let localDate: String   // YYYY-MM-DD in the subscription's timezone

        public init(subscription: NotificationSubscription, localDate: String) {
            self.subscription = subscription
            self.localDate = localDate
        }
    }

    public static func fire(subs: [NotificationSubscription], now: Date) -> [FiredSubscription] {
        subs.compactMap { sub in
            guard sub.enabled else { return nil }
            guard let tz = TimeZone(identifier: sub.timezone) else { return nil }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = tz
            let components = calendar.dateComponents([.year, .month, .day, .hour, .weekday], from: now)
            guard let weekday = components.weekday,
                  let currentHour = components.hour,
                  let day = DayOfWeek.from(calendarWeekday: weekday)
            else { return nil }
            guard sub.daysOfWeek.contains(day) else { return nil }
            guard currentHour == sub.hour else { return nil }
            let localDate = formatLocalDate(components: components)
            if sub.lastSentLocalDate == localDate { return nil }
            return FiredSubscription(subscription: sub, localDate: localDate)
        }
    }

    /// Format `DateComponents` (with .year/.month/.day populated) as YYYY-MM-DD.
    public static func formatLocalDate(components: DateComponents) -> String {
        let y = components.year ?? 0
        let m = components.month ?? 0
        let d = components.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    /// Convenience: compute YYYY-MM-DD for `now` in the given timezone.
    public static func localDate(now: Date, timezone: String) -> String? {
        guard let tz = TimeZone(identifier: timezone) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        return formatLocalDate(components: components)
    }
}
