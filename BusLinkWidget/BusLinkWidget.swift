import WidgetKit
import SwiftUI

private struct WidgetEvent: Decodable {
    let label: String
    let at: String
    let source: String
}

private struct WidgetServerPeriod: Decodable {
    let id: String
    let watch: String?
    let reason: String?
    let monitoringEnabled: Bool?
    let schoolOffReason: String?
}

private struct WidgetBusState: Decodable {
    let period: String
    let bus: Bool
    let shaira: Bool
    let busAt: String?
    let shairaAt: String?
    let events: [WidgetEvent]
    let serverPeriod: WidgetServerPeriod
}

private struct BusLinkWidgetEntry: TimelineEntry {
    let date: Date
    let state: WidgetBusState?
    let error: Bool

    static let placeholder = BusLinkWidgetEntry(date: Date(), state: nil, error: false)
}

private struct BusLinkWidgetProvider: TimelineProvider {
    private let stateURL = URL(string: "https://buslink.mikegyver.workers.dev/api/state")!

    func placeholder(in context: Context) -> BusLinkWidgetEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (BusLinkWidgetEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task { completion(await load()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BusLinkWidgetEntry>) -> Void) {
        Task {
            let entry = await load()
            let refresh = nextRefresh(after: entry.date, state: entry.state)
            completion(Timeline(entries: [entry], policy: .after(refresh)))
        }
    }

    private func load() async -> BusLinkWidgetEntry {
        do {
            var request = URLRequest(url: stateURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 10
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return BusLinkWidgetEntry(date: Date(), state: nil, error: true)
            }
            let state = try JSONDecoder().decode(WidgetBusState.self, from: data)
            return BusLinkWidgetEntry(date: Date(), state: state, error: false)
        } catch {
            return BusLinkWidgetEntry(date: Date(), state: nil, error: true)
        }
    }

    private func nextRefresh(after date: Date, state: WidgetBusState?) -> Date {
        // WidgetKit owns the actual refresh cadence. During an active watch we ask
        // for a fresh timeline every minute; the system may coalesce or delay it.
        if state?.serverPeriod.watch != nil && state?.serverPeriod.monitoringEnabled != false {
            return date.addingTimeInterval(60)
        }
        return BusLinkWidgetSchedule.nextWatchStart(after: date) ?? date.addingTimeInterval(3600)
    }
}

private enum BusLinkWidgetSchedule {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        return calendar
    }

    static func nextWatchStart(after date: Date) -> Date? {
        let startOfToday = calendar.startOfDay(for: date)
        for dayOffset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday),
                  let weekday = calendar.dateComponents([.weekday], from: day).weekday,
                  (2...6).contains(weekday) else { continue }
            for (hour, minute) in [(8, 15), (16, 15)] {
                if let start = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day), start > date {
                    return start
                }
            }
        }
        return nil
    }
}

private struct BusLinkWidgetView: View {
    let entry: BusLinkWidgetEntry

    private let navy = Color(red: 0.045, green: 0.09, blue: 0.17)
    private let mint = Color(red: 0.36, green: 0.91, blue: 0.75)

    private var state: WidgetBusState? { entry.state }
    private var reason: String? { state?.serverPeriod.reason }
    private var watch: String? { state?.serverPeriod.watch }
    private var ready: Bool { state?.bus == true && state?.shaira == true }

    private var headline: String {
        if entry.error { return "CHECK APP" }
        if reason == "weekend" { return "WEEKEND" }
        if reason == "school-off" { return "SCHOOL OFF" }
        if ready { return "READY" }
        if state?.bus == true { return "BUS NEAR" }
        if state?.shaira == true { return "SHAIRA THERE" }
        if watch == "AM" { return "AM WATCH" }
        if watch == "PM" { return "PM WATCH" }
        return "STANDBY"
    }

    private var busText: String {
        guard state?.bus == true else { return "WAITING" }
        return watch == "AM" ? "1-MILE" : "ALMOST HOME"
    }

    private var shairaText: String { state?.shaira == true ? "AT STOP" : "AWAY" }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "bus.fill")
                Text("BUSLINK").font(.caption2.bold()).tracking(1.2)
                Spacer(minLength: 0)
                Circle().fill(entry.error ? Color.orange : mint).frame(width: 7, height: 7)
            }
            .foregroundStyle(mint)

            Text(headline)
                .font(.title3.bold())
                .foregroundStyle(ready ? mint : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 0)

            Label(busText, systemImage: "bus.fill")
                .font(.caption.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Label(shairaText, systemImage: "figure.walk")
                .font(.caption.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(entry.date.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.58))
        }
        .padding(14)
        .foregroundStyle(.white)
        .containerBackground(for: .widget) { navy }
    }
}

struct BusLinkStatusWidget: Widget {
    let kind = "BusLinkStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BusLinkWidgetProvider()) { entry in
            BusLinkWidgetView(entry: entry)
        }
        .configurationDisplayName("BusLink Status")
        .description("Glanceable school-bus and rendezvous status for iPhone, StandBy, and CarPlay.")
        .supportedFamilies([.systemSmall])
        .containerBackgroundRemovable(true)
    }
}

@main
struct BusLinkWidgetBundle: WidgetBundle {
    var body: some Widget {
        BusLinkStatusWidget()
    }
}
