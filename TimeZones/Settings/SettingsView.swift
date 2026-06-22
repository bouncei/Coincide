import SwiftUI
import ServiceManagement

/// Reopenable settings: manage zones, choose the menu bar reference, time
/// format, launch-at-login, and About.
struct SettingsView: View {
    @EnvironmentObject var store: ZoneStore
    @State private var showingAddSheet = false
    @State private var addSelection: Set<String> = []
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var renaming: SavedZone?
    @State private var renameText = ""

    var body: some View {
        Form {
            zonesSection
            menuBarSection
            appearanceSection
            generalSection
            aboutSection
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 600)
        .sheet(isPresented: $showingAddSheet) { addSheet }
    }

    // MARK: Zones

    private var zonesSection: some View {
        Section {
            ForEach(store.displayZones) { zone in
                HStack(spacing: 10) {
                    Image(systemName: store.isHome(zone) ? "house.fill" : "globe")
                        .foregroundStyle(store.isHome(zone) ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(zone.displayName).font(.system(size: 13, weight: .medium))
                        Text("\(zone.tzIdentifier)  ·  \(TimeFormatting.gmtOffsetLabel(for: zone.timeZone))")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if store.isReference(zone) {
                        Image(systemName: "menubar.rectangle").foregroundStyle(.tint).help("Shown in the menu bar")
                    }
                    Menu {
                        Button("Rename…") { renaming = zone; renameText = zone.displayName }
                        Button("Show in Menu Bar") { store.setReference(zone) }.disabled(store.isReference(zone))
                        Button("Set as Home") { store.setHome(zone) }.disabled(store.isHome(zone))
                        Divider()
                        Button("Remove", role: .destructive) { store.removeZone(zone) }.disabled(store.isHome(zone))
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                .padding(.vertical, 2)
            }
            .onMove { store.move(fromOffsets: $0, toOffset: $1) }

            Button {
                addSelection = []
                showingAddSheet = true
            } label: {
                Label("Add Time Zone", systemImage: "plus")
            }
        } header: {
            Text("Your Time Zones")
        } footer: {
            Text("Drag to reorder. Home is always shown first.")
        }
        .alert("Rename Zone", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $renameText)
            Button("Save") { if let z = renaming { store.rename(z, to: renameText) }; renaming = nil }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }

    private var addSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Time Zones").font(.headline)
                Spacer()
                Text("\(addSelection.count) selected").font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            ZonePickerView(
                selection: $addSelection,
                excluded: Set(store.zones.map(\.tzIdentifier))
            )
            Divider()
            HStack {
                Button("Cancel") { showingAddSheet = false }
                Spacer()
                Button("Add \(addSelection.count == 0 ? "" : "\(addSelection.count) ")Zone\(addSelection.count == 1 ? "" : "s")") {
                    for id in addSelection.sorted() { store.addZone(id) }
                    showingAddSheet = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(addSelection.isEmpty)
            }
            .padding()
        }
        .frame(width: 440, height: 520)
    }

    // MARK: Menu bar

    private var menuBarSection: some View {
        Section("Menu Bar") {
            Picker("Show this zone", selection: Binding(
                get: { store.referenceZone?.id },
                set: { id in if let z = store.zones.first(where: { $0.id == id }) { store.setReference(z) } }
            )) {
                ForEach(store.displayZones) { Text($0.displayName).tag(Optional($0.id)) }
            }
        }
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Time format", selection: $store.hourFormat) {
                ForEach(HourFormat.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: General

    private var generalSection: some View {
        Section("General") {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in setLaunchAtLogin(newValue) }
            Button("Run Setup Again") { store.resetOnboarding() }
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Revert the toggle if the system rejected the change.
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    // MARK: About

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
            Link("View on GitHub", destination: URL(string: "https://github.com/joshuainyang/TimeZones")!)
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
