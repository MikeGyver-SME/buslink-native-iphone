import Foundation

/// Local guardrail for BusLink's Central-time school-week windows.
/// The Worker remains authoritative for weekday school holidays/breaks.
enum WatchSchedule {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        return calendar
    }

    static func isWeekend(at date: Date = Date()) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    static func watch(at date: Date = Date()) -> String? {
        let fields = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = fields.weekday, (2...6).contains(weekday),
              let hour = fields.hour, let minute = fields.minute else { return nil }
        let minuteOfDay = hour * 60 + minute
        if (8 * 60 + 15 ..< 9 * 60).contains(minuteOfDay) { return "AM" }
        if (16 * 60 + 15 ..< 17 * 60).contains(minuteOfDay) { return "PM" }
        return nil
    }

    static func dayID(at date: Date = Date()) -> String {
        let fields = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", fields.year ?? 0, fields.month ?? 0, fields.day ?? 0)
    }

    static func periodID(at date: Date = Date()) -> String? {
        guard let watch = watch(at: date) else { return nil }
        return "\(dayID(at: date))-\(watch)"
    }

    static func secondsUntilNextStart(after date: Date = Date()) -> TimeInterval {
        let startOfToday = calendar.startOfDay(for: date)
        for dayOffset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday),
                  let weekday = calendar.dateComponents([.weekday], from: day).weekday,
                  (2...6).contains(weekday) else { continue }
            for (hour, minute) in [(8, 15), (16, 15)] {
                guard let start = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                      start > date else { continue }
                return start.timeIntervalSince(date)
            }
        }
        return 60
    }
}
