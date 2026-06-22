import SwiftUI

/// A searchable timezone picker over the full IANA catalog. Used both in
/// onboarding and settings. Multi-select by default; toggling a row adds or
/// removes its identifier from `selection`.
struct ZonePickerView: View {
    @Binding var selection: Set<String>
    var excluded: Set<String> = []
    var singleSelect: Bool = false

    @State private var query = ""

    private var results: [CatalogZone] {
        TimezoneCatalog.search(query).filter { !excluded.contains($0.id) }
    }

    private var common: [CatalogZone] {
        TimezoneCatalog.common.filter { !excluded.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            List {
                if query.isEmpty {
                    if !common.isEmpty {
                        Section("Common") {
                            ForEach(common) { row($0) }
                        }
                    }
                    Section("All time zones") {
                        ForEach(results) { row($0) }
                    }
                } else {
                    Section("\(results.count) result\(results.count == 1 ? "" : "s")") {
                        ForEach(results) { row($0) }
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search city, region, or GMT offset", text: $query)
                .textFieldStyle(.plain)
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func row(_ zone: CatalogZone) -> some View {
        let tz = TimeZone(identifier: zone.id) ?? .current
        let isSelected = selection.contains(zone.id)
        return Button {
            toggle(zone.id)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(zone.city).font(.system(size: 13))
                    Text("\(zone.region)  ·  \(TimeFormatting.gmtOffsetLabel(for: tz))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(TimeFormatting.time(in: tz, at: Date(), format: .twelveHour))
                    .font(.system(size: 12, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ id: String) {
        if singleSelect {
            selection = [id]
            return
        }
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }
}
