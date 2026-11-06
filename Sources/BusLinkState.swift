import Foundation
import UserNotifications
import WidgetKit

enum BusLinkDate {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parse(_ raw: String) -> Date? {
        fractional.date(from: raw) ?? standard.date(from: raw)
    }
}

struct BusEvent: Decodable, Identifiable {
    let label: String
    let at: String
    let source: String
    var id: String { "\(at)|\(label)|\(source)" }
    var date: Date? { BusLinkDate.parse(at) }
}

struct BusLinkDailySchedule: Decodable {
    let amEnabled: Bool
    let pmEnabled: Bool
    let amReason: String?
    let pmReason: String?
}

struct ServerPeriod: Decodable {
    let id: String
    let watch: String?
    let reason: String?
    let monitoringEnabled: Bool?
    let schoolOffReason: String?
    let pausedWatch: String?
    let schedule: BusLinkDailySchedule?
}

struct BusState: Decodable {
    let period: String
    let bus: Bool
    let shaira: Bool
    let busAt: String?
    let shairaAt: String?
    let events: [BusEvent]
    let serverPeriod: ServerPeriod
}

@MainActor
final class BusLinkModel: ObservableObject {
    @Published private(set) var state: BusState?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var error: String?
    @Published private(set) var notificationsEnabled = false
    @Published private(set) var loading = false
    @Published private(set) var clock = Date()

    private let stateURL = URL(string: "https://buslink-v2.mikegyver.workers.dev/api/state")!
    private let seenKey = "buslink.native.seen.eventIDs.v1"
    private let seededKey = "buslink.native.seeded.v1"

    var watch: String? { WatchSchedule.watch(at: clock) }
    var schoolOffReason: String? {
        guard state?.serverPeriod.id.hasPrefix(WatchSchedule.dayID(at: clock)) == true,
              state?.serverPeriod.reason == "school-off" else { return nil }
        return state?.serverPeriod.schoolOffReason ?? "School holiday / break"
    }
    var pausedWatch: String? {
        guard let server = state?.serverPeriod,
              server.id == "\(WatchSchedule.dayID(at: clock))-OFF",
              server.reason == "watch-paused", server.pausedWatch == watch else { return nil }
        return server.pausedWatch
    }
    var pauseReason: String? { pausedWatch == nil ? nil : state?.serverPeriod.schoolOffReason ?? "Scheduled exception" }
    var otherWatchDetail: String {
        guard let pausedWatch, let schedule = state?.serverPeriod.schedule else { return "Check today's schedule in admin." }
        if pausedWatch == "AM" {
            return schedule.pmEnabled ? "Afternoon watch ON • 4:15–5:00 PM CT" : "Afternoon watch OFF"
        }
        return schedule.amEnabled ? "Morning watch ON • 8:15–9:00 AM CT" : "Morning watch OFF"
    }
    var schedulePaused: Bool { pausedWatch != nil || schoolOffReason != nil || WatchSchedule.isWeekend(at: clock) }
    var onWatch: Bool { watch != nil && !schedulePaused }
    var currentState: BusState? {
        guard onWatch, let state, state.period == WatchSchedule.periodID(at: clock) else { return nil }
        return state
    }

    func syncClock() {
        clock = Date()
        let today = WatchSchedule.dayID(at: clock)
        if let state, !state.serverPeriod.id.hasPrefix(today) {
            self.state = nil; lastUpdated = nil; error = nil
        }
    }

    func refresh() async {
        syncClock()
        let requestedPeriod = WatchSchedule.periodID(at: clock) ?? "\(WatchSchedule.dayID(at: clock))-OFF"
        let requestedWatch = watch
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            var request = URLRequest(url: stateURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 12
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw BusLinkError.badHTTP((response as? HTTPURLResponse)?.statusCode ?? 0)
            }
            let next = try JSONDecoder().decode(BusState.self, from: data)
            let today = WatchSchedule.dayID(at: clock)
            let activeMatch = next.period == requestedPeriod && next.serverPeriod.id == requestedPeriod && next.serverPeriod.watch == requestedWatch
            let pausedMatch = next.serverPeriod.id == "\(today)-OFF" && next.period == next.serverPeriod.id &&
                (next.serverPeriod.reason == "school-off" || next.serverPeriod.reason == "weekend" ||
                 (next.serverPeriod.reason == "watch-paused" && next.serverPeriod.pausedWatch != nil && next.serverPeriod.pausedWatch == requestedWatch) ||
                 (next.serverPeriod.reason == "off-hours" && requestedWatch == nil))
            guard activeMatch || pausedMatch else { throw BusLinkError.invalidPeriod }
            guard !Task.isCancelled, (WatchSchedule.periodID() ?? "\(WatchSchedule.dayID())-OFF") == requestedPeriod else { return }
            state = next
            lastUpdated = Date()
            error = nil
            // If the user opens BusLink, ask WidgetKit to refresh the CarPlay/iPhone
            // status widget as well. WidgetKit still owns the actual scheduling.
            WidgetCenter.shared.reloadTimelines(ofKind: "BusLinkStatusWidget")
            await notifyForNewEvents(next)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsEnabled = settings.authorizationStatus == .authorized
    }

    func enableNotifications() async {
        do {
            notificationsEnabled = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            notificationsEnabled = false
        }
    }

    private func notifyForNewEvents(_ next: BusState) async {
        var seen = Set(UserDefaults.standard.stringArray(forKey: seenKey) ?? [])
        let ids = next.events.map { "\(next.period)|\($0.id)" }
        if !UserDefaults.standard.bool(forKey: seededKey) {
            UserDefaults.standard.set(Array(ids), forKey: seenKey)
            UserDefaults.standard.set(true, forKey: seededKey)
            return
        }
        let fresh = next.events.filter { !seen.contains("\(next.period)|\($0.id)") }
        seen.formUnion(ids)
        UserDefaults.standard.set(Array(seen.sorted().suffix(120)), forKey: seenKey)
        guard notificationsEnabled, onWatch else { return }
        for event in fresh.reversed() {
            guard let date = event.date, abs(date.timeIntervalSinceNow) < 180 else { continue }
            let content = UNMutableNotificationContent()
            content.title = "BusLink"
            content.body = event.label
            content.sound = .default
            try? await UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            )
        }
    }
}

enum BusLinkError: LocalizedError {
    case badHTTP(Int)
    case invalidPeriod
    var errorDescription: String? {
        switch self {
        case .badHTTP(let code): return "BusLink returned HTTP \(code)."
        case .invalidPeriod: return "The server returned a mismatched watch period."
        }
    }
}
