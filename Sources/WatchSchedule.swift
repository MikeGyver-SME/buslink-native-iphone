import Foundation

/// The same weekday watch windows as the family's BusLink schedule, in Central time.
enum WatchSchedule {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        return calendar
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

    static func periodID(at date: Date = Date()) -> String? {
        guard let watch = watch(at: date) else { return nil }
        let fields = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = fields.year, let month = fields.month, let day = fields.day else { return nil }
        return String(format: "%04d-%02d-%02d-%@", year, month, day, watch)
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
        return 60 // Defensive fallback; still does not make a network request.
    }
}
