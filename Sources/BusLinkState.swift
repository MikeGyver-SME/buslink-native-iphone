import Foundation
import UserNotifications

enum BusLinkDate {
    // Worker timestamps are ISO-8601 UTC strings and normally include fractional seconds.
    // ISO8601DateFormatter does not parse fractional seconds unless explicitly enabled.
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    // Keep a fallback for valid ISO-8601 timestamps that omit fractional seconds.
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

struct ServerPeriod: Decodable {
    let id: String
    let watch: String?
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

    // No write endpoint or event secret is included in the iPhone app.
    private let stateURL = URL(string: "https://buslink.mikegyver.workers.dev/api/state")!
    private let seenKey = "buslink.native.seen.eventIDs.v1"
    private let seededKey = "buslink.native.seeded.v1"

    var watch: String? { WatchSchedule.watch(at: clock) }
    var onWatch: Bool { watch != nil }
    var currentState: BusState? {
        guard let state, state.period == WatchSchedule.periodID(at: clock) else { return nil }
        return state
    }

    func syncClock() {
        clock = Date()
        if currentState == nil { state = nil; lastUpdated = nil; error = nil }
    }

    func refresh() async {
        syncClock()
        guard let requestedPeriod = WatchSchedule.periodID(at: clock) else { return }
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
            guard next.period == requestedPeriod,
                  next.serverPeriod.id == requestedPeriod,
                  next.serverPeriod.watch == watch else { throw BusLinkError.invalidPeriod }
            guard !Task.isCancelled, WatchSchedule.periodID() == requestedPeriod else { return }
            state = next
            lastUpdated = Date()
            error = nil
            await notifyForNewEvents(next)
        } catch {
            // Keep the last valid state on screen. Notification failures never affect health.
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
            return // Existing history is the baseline on first launch.
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
