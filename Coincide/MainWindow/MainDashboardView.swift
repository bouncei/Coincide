import SwiftUI
import AppKit

/// The full "app interface" opened from the menu bar: every zone with a
/// 24-hour day/night band, plus a time scrubber to shift time and find a slot
/// that works across zones. All bands share one instant axis (the home zone's
/// day), so a vertical marker reads the same moment across every row.
struct MainDashboardView: View {
    @EnvironmentObject var store: ZoneStore
    @EnvironmentObject var clock: MinuteClock
    @EnvironmentObject var calendar: CalendarHub
    @Environment(\.openSettings) private var openSettings

    /// nil = follow the live clock; non-nil = a scrubbed instant.
    @State private var scrubbed: Date?
    @State private var showingAdd = false
    @State private var addSelection: Set<String> = []

    private let nameWidth: CGFloat = 156
    private let timeWidth: CGFloat = 92

    private var homeTZ: TimeZone { store.homeTimeZone }

    /// Start of "today" in the home zone — the left edge of the 24h axis.
    private var dayStart: Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = homeTZ
        return cal.startOfDay(for: clock.now)
    }

    private var selectedInstant: Date { scrubbed ?? clock.now }

    private var fraction: Double {
        max(0, min(1, selectedInstant.timeIntervalSince(dayStart) / 86_400))
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if store.zones.isEmpty {
                emptyState
            } else {
                readout
                axisAndScrubber
                if calendar.isActive {
                    eventsLane
                }
                Divider().padding(.top, 4)
                rows
            }
        }
        .frame(minWidth: 580, minHeight: 380)
        .sheet(isPresented: $showingAdd) { addSheet }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)
            Text("Coincide").font(.system(size: 14, weight: .bold))
            Spacer()
            Button { addSelection = []; showingAdd = true } label: {
                Image(systemName: "plus")
            }
            .help("Add a time zone")
            Button { NSApp.activate(ignoringOtherApps: true); openSettings() } label: {
                Image(systemName: "gearshape")
            }
            .help("Settings")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: Readout

    private var readout: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text(scrubbed == nil ? "Right now" : "At the selected time")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(homeReadout)
                    .font(.system(size: 17, weight: .bold))
                    .monospacedDigit()
            }
            Spacer()
            if scrubbed != nil {
                Text(offsetText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Button("Now") { scrubbed = nil }
                .controlSize(.small)
                .disabled(scrubbed == nil)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    /// e.g. "Sat 3:00 PM · Lagos".
    private var homeReadout: String {
        let df = DateFormatter()
        df.locale = .current
        df.timeZone = homeTZ
        df.dateFormat = store.hourFormat == .twelveHour ? "EEE h:mm a" : "EEE HH:mm"
        let city = store.homeZone?.cityName ?? "Home"
        return "\(df.string(from: selectedInstant)) · \(city)"
    }

    private var offsetText: String {
        let minutes = Int((selectedInstant.timeIntervalSince(clock.now) / 60).rounded())
        if minutes == 0 { return "now" }
        let sign = minutes > 0 ? "+" : "−"
        let m = abs(minutes)
        let h = m / 60
        let mm = m % 60
        if h == 0 { return "\(sign)\(mm)m" }
        if mm == 0 { return "\(sign)\(h)h" }
        return "\(sign)\(h)h \(mm)m"
    }

    // MARK: Axis + scrubber (inset to align with the bands)

    private var axisAndScrubber: some View {
        VStack(spacing: 2) {
            HStack(spacing: 0) {
                Spacer().frame(width: nameWidth)
                HStack(spacing: 0) {
                    axisLabel("12a"); Spacer(); axisLabel("6a"); Spacer()
                    axisLabel("12p"); Spacer(); axisLabel("6p"); Spacer(); axisLabel("12a")
                }
                Spacer().frame(width: timeWidth)
            }
            HStack(spacing: 0) {
                Spacer().frame(width: nameWidth)
                Slider(value: Binding(
                    get: { fraction },
                    set: { scrubbed = dayStart.addingTimeInterval($0 * 86_400) }
                ), in: 0...1)
                Spacer().frame(width: timeWidth)
            }
        }
        .padding(.horizontal, 16)
    }

    private func axisLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 9)).foregroundStyle(.tertiary)
    }

    // MARK: Events lane

    @ViewBuilder
    private var eventsLane: some View {
        let blocks = CalendarLogic.timelineBlocks(for: calendar.events, dayStart: dayStart)
        if !blocks.isEmpty {
            HStack(spacing: 0) {
                Spacer().frame(width: nameWidth)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        ForEach(blocks) { block in
                            let x = block.startFraction * geo.size.width
                            let w = max(3, (block.endFraction - block.startFraction) * geo.size.width)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill((Color(hex: block.event.calendarColorHex) ?? .accentColor).opacity(0.85))
                                .frame(width: w, height: 16)
                                .overlay(alignment: .leading) {
                                    Text(block.event.title)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .padding(.leading, 4)
                                        .frame(width: w, alignment: .leading)
                                }
                                .offset(x: x)
                                .help(block.event.title)
                        }
                    }
                    .frame(height: 18)
                }
                .frame(height: 18)
                Spacer().frame(width: timeWidth)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
        }
    }

    // MARK: Rows

    private var rows: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(store.displayZones) { zone in
                    DashboardRow(
                        zone: zone,
                        dayStart: dayStart,
                        selectedInstant: selectedInstant,
                        fraction: fraction,
                        homeTZ: homeTZ,
                        isHome: store.isHome(zone),
                        hourFormat: store.hourFormat,
                        nameWidth: nameWidth,
                        timeWidth: timeWidth
                    )
                    Divider().padding(.leading, 16)
                }
            }
            .padding(.top, 6)
        }
    }

    // MARK: Add sheet

    private var addSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Time Zones").font(.headline)
                Spacer()
                Text("\(addSelection.count) selected").font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            ZonePickerView(selection: $addSelection, excluded: Set(store.zones.map(\.tzIdentifier)))
            Divider()
            HStack {
                Button("Cancel") { showingAdd = false }
                Spacer()
                Button("Add \(addSelection.isEmpty ? "" : "\(addSelection.count) ")Zone\(addSelection.count == 1 ? "" : "s")") {
                    for id in addSelection.sorted() { store.addZone(id) }
                    showingAdd = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(addSelection.isEmpty)
            }
            .padding()
        }
        .frame(width: 440, height: 520)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "globe").font(.system(size: 30)).foregroundStyle(.tertiary)
            Text("No zones yet").font(.system(size: 15, weight: .semibold))
            Button("Add a Time Zone") { addSelection = []; showingAdd = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// One row: name/flag, a 24-hour day/night band with the instant marker, and
/// the zone's local time at the selected instant.
private struct DashboardRow: View {
    let zone: SavedZone
    let dayStart: Date
    let selectedInstant: Date
    let fraction: Double
    let homeTZ: TimeZone
    let isHome: Bool
    let hourFormat: HourFormat
    let nameWidth: CGFloat
    let timeWidth: CGFloat

    private var dayLabel: String? {
        TimeFormatting.dayOffsetLabel(home: homeTZ, other: zone.timeZone, at: selectedInstant)
    }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 9) {
                Text(zone.flag).font(.system(size: 19))
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(zone.displayName).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        if isHome {
                            Image(systemName: "house.fill").font(.system(size: 8)).foregroundStyle(.tint)
                        }
                    }
                    Text(zone.countryName ?? zone.cityName)
                        .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .frame(width: nameWidth, alignment: .leading)

            band

            VStack(alignment: .trailing, spacing: 1) {
                Text(TimeFormatting.time(in: zone.timeZone, at: selectedInstant, format: hourFormat))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                if let dayLabel {
                    Text(dayLabel)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(dayLabel == "Yesterday" ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                }
            }
            .frame(width: timeWidth, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var band: some View {
        HStack(spacing: 1) {
            ForEach(0..<24, id: \.self) { hour in
                let phase = DayPhase.current(in: zone.timeZone, at: dayStart.addingTimeInterval(Double(hour) * 3600))
                Rectangle().fill(phase.bandColor)
            }
        }
        .frame(height: 22)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(alignment: .leading) {
            GeometryReader { geo in
                Rectangle()
                    .fill(.white)
                    .frame(width: 2)
                    .shadow(color: .black.opacity(0.4), radius: 1.5)
                    .offset(x: fraction * geo.size.width - 1)
            }
        }
    }
}
