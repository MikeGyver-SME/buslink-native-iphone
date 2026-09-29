import SwiftUI

struct DashboardView: View {
    @StateObject private var model = BusLinkModel()
    @Environment(\.scenePhase) private var scenePhase

    private let navy = Color(red: 0.045, green: 0.09, blue: 0.17)
    private let card = Color(red: 0.09, green: 0.16, blue: 0.27)
    private let mint = Color(red: 0.36, green: 0.91, blue: 0.75)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                watchCard
                rendezvousCard
                HStack(spacing: 12) {
                    statusCard(icon: "bus.fill", title: "COLIN’S BUS",
                               value: model.currentState?.bus == true ? (model.watch == "PM" ? "Almost home" : "1-mile Loop") : "Waiting",
                               time: model.currentState?.busAt, active: model.currentState?.bus == true)
                    statusCard(icon: "figure.walk", title: "SHAIRA",
                               value: model.currentState?.shaira == true ? "At bus stop" : "Away",
                               time: model.currentState?.shairaAt, active: model.currentState?.shaira == true)
                }
                eventsCard
                controls
            }
            .padding(20)
        }
        .background(navy.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .refreshable { await model.refresh() }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await model.updateNotificationStatus()
            while !Task.isCancelled {
                model.syncClock()
                if model.onWatch { await model.refresh() }
                let seconds = model.onWatch ? 10 : max(1, WatchSchedule.secondsUntilNextStart())
                try? await Task.sleep(for: .seconds(seconds))
                guard !Task.isCancelled else { break }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("BUSLINK").font(.caption.bold()).tracking(3).foregroundStyle(mint)
                Text("Family rendezvous").font(.largeTitle.bold())
                Text("Colin’s bus • live field status").foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
            Image(systemName: "bus.doubledecker.fill")
                .font(.title2).foregroundStyle(navy)
                .frame(width: 54, height: 54)
                .background(mint, in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.top, 12)
    }

    private var watchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(model.onWatch ? (model.watch == "AM" ? "MORNING WATCH" : "AFTERNOON WATCH") : "OFF WATCH",
                      systemImage: model.onWatch ? "dot.radiowaves.left.and.right" : "moon.stars.fill")
                    .font(.subheadline.bold()).foregroundStyle(model.onWatch ? mint : .white.opacity(0.65))
                Spacer()
                Text(model.onWatch ? (model.error == nil && model.lastUpdated != nil ? "LIVE" : "WATCH") : "STANDBY")
                    .font(.caption.bold()).tracking(1)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background((model.onWatch ? mint : .gray).opacity(0.18), in: Capsule())
            }
            Text("8:15–9:00 AM  •  4:15–5:00 PM CT")
                .font(.caption).foregroundStyle(.white.opacity(0.65))
            if !model.onWatch {
                Label("Paused until the next weekday watch. No Worker requests now; connection untested.",
                      systemImage: "pause.circle.fill")
                    .font(.caption).foregroundStyle(.white.opacity(0.65))
            } else if let error = model.error {
                Label("Worker check failed: \(error)", systemImage: "wifi.exclamationmark")
                    .font(.caption).foregroundStyle(.orange)
                if let date = model.lastUpdated {
                    Text("Last successful update: \(date.formatted(date: .omitted, time: .standard)). Retrying while on watch.")
                        .font(.caption).foregroundStyle(.white.opacity(0.65))
                } else {
                    Text("Retrying while on watch.")
                        .font(.caption).foregroundStyle(.white.opacity(0.65))
                }
            } else if let date = model.lastUpdated {
                Label("Updated \(date.formatted(date: .omitted, time: .standard))", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(mint)
            } else if model.loading {
                ProgressView("Connecting to BusLink…").tint(mint)
            } else {
                Label("Waiting for the first Worker check…", systemImage: "clock")
                    .font(.caption).foregroundStyle(.white.opacity(0.65))
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(card, in: RoundedRectangle(cornerRadius: 22))
    }

    private var rendezvousCard: some View {
        let bus = model.currentState?.bus == true && model.onWatch
        let shaira = model.currentState?.shaira == true && model.onWatch
        let ready = bus && shaira
        let title = ready ? "RENDEZVOUS READY" : (bus && model.watch == "AM" ? "GO TO THE BUS" : (model.onWatch ? "WAITING" : "OFF WATCH"))
        let detail = ready ? (model.watch == "AM" ? "The 1-mile Loop alert and Shaira’s arrival are confirmed." : "Shaira is at the stop and Colin’s bus is almost home.")
            : bus ? (model.watch == "AM" ? "The bus reached the 1-mile Loop." : "The bus is almost home; waiting for Shaira.")
            : shaira ? "Shaira is at the stop; waiting for the bus."
            : model.onWatch ? "Your Shortcuts send events to the existing BusLink Worker."
            : "Status checks resume during the next weekday watch. Shortcuts continue sending events independently."
        return VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2.bold()).foregroundStyle(ready || bus ? navy : .white)
            Text(detail).font(.subheadline).foregroundStyle(ready || bus ? navy.opacity(0.8) : .white.opacity(0.7))
        }
        .padding(22).frame(maxWidth: .infinity, alignment: .leading)
        .background(ready || bus ? mint : card, in: RoundedRectangle(cornerRadius: 24))
    }

    private func statusCard(icon: String, title: String, value: String, time: String?, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(active ? mint : .white.opacity(0.55))
            Text(title).font(.caption.bold()).tracking(1.2).foregroundStyle(.white.opacity(0.6))
            Text(value).font(.headline).lineLimit(2).minimumScaleFactor(0.8)
            Text(timestamp(time) ?? "No event yet").font(.caption).foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .leading)
        .padding(16).background(card, in: RoundedRectangle(cornerRadius: 20))
    }

    private var eventsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EVENT LOG").font(.caption.bold()).tracking(2).foregroundStyle(mint)
            if let events = model.currentState?.events, !events.isEmpty, model.onWatch {
                ForEach(events) { event in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "circle.fill").font(.system(size: 8)).foregroundStyle(mint).padding(.top, 7)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.label).font(.subheadline.bold())
                            Text("\(timestamp(event.at) ?? "Unknown time") • \(event.source)")
                                .font(.caption).foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    if event.id != events.last?.id { Divider().overlay(.white.opacity(0.12)) }
                }
            } else {
                Text(model.onWatch ? "No events for this watch period." : "Event log resumes during the next watch.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(card, in: RoundedRectangle(cornerRadius: 22))
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { Task { await model.refresh() } } label: {
                Label(model.onWatch ? "Refresh now" : "Refresh available on watch", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity).padding(14)
            }
            .buttonStyle(.borderedProminent).tint(mint)
            .disabled(!model.onWatch || model.loading)
            if !model.notificationsEnabled {
                Button { Task { await model.enableNotifications() } } label: {
                    Label("Enable alerts while app is open", systemImage: "bell.badge")
                        .frame(maxWidth: .infinity).padding(10)
                }.buttonStyle(.bordered)
            }
            Text("The app refreshes while open. Keep your iPhone Shortcuts and Windows Watchdog for event detection and laptop alerts. Background iPhone alerts are not guaranteed by this version.")
                .font(.caption).foregroundStyle(.white.opacity(0.55))
        }
        .padding(.bottom, 16)
    }

    private func timestamp(_ raw: String?) -> String? {
        guard let raw, let date = ISO8601DateFormatter().date(from: raw) else { return nil }
        return date.formatted(date: .omitted, time: .standard)
    }
}
