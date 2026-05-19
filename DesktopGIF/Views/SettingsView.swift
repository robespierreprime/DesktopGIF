// SettingsView.swift — Étape E

import SwiftUI
import AppKit
import ServiceManagement
internal import UniformTypeIdentifiers

struct SettingsView: View {
    var body: some View {
        TabView {
            GIFsSettingsTab()
                .tabItem { Label("GIFs", systemImage: "photo.fill") }

            GroupsSettingsTab()
                .tabItem { Label("Groups", systemImage: "folder.fill") }

            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }

            CreditsTab()
                .tabItem { Label("Credits", systemImage: "heart.fill") }
        }
        .frame(width: 620, height: 540)
        .padding()
    }
}

// MARK: – Onglet GIFs (refondu E1 + E2)

private struct GIFsSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @State private var isImporting = false
    @State private var removeTarget: GIFItem? = nil
    @State private var showRemoveAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Barre d'outils ──────────────────────────────────────────
            HStack {
                Button {
                    isImporting = true
                } label: {
                    Label("Add a GIF…", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Spacer()

                Button {
                    appState.resetAllWindows()
                } label: {
                    Label("Reset all windows", systemImage: "arrow.counterclockwise")
                }
                .controlSize(.small)
            }
            .padding(.bottom, 10)

            // ── Liste GIFs ──────────────────────────────────────────────
            if appState.gifs.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                        Text("No GIFs added yet")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                        Text("Click \"Add a GIF…\" to get started.")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                List(appState.gifs) { item in
                    GIFFullRow(
                        item: item,
                        onRemove: {
                            removeTarget = item
                            showRemoveAlert = true
                        }
                    )
                    .environmentObject(appState)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .padding()
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.gif],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                appState.addGIF(at: url.path)
            }
        }
        .alert("Remove GIF?", isPresented: $showRemoveAlert, presenting: removeTarget) { target in
            Button("Remove", role: .destructive) { appState.remove(target) }
            Button("Cancel", role: .cancel) {}
        } message: { target in
            Text("\(target.label) will be removed from the desktop. This cannot be undone.")
        }
    }
}

// MARK: – Ligne GIF complète

private struct GIFFullRow: View {
    @EnvironmentObject var appState: AppState
    let item: GIFItem
    let onRemove: () -> Void

    private var screens: [NSScreen] { NSScreen.screens }

    // Formatage de la vitesse : "0.25×", "1×", "2×", etc.
    private func speedLabel(_ v: Double) -> String {
        let formatted = v.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(v))
            : String(format: "%g", v)
        return "\(formatted)×"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            // ── Ligne 1 : nom + toggles + écran ──────────────────────────
            HStack(spacing: 8) {
                Text(item.label)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Toggle visibilité
                Toggle(isOn: Binding(
                    get: { item.isVisible },
                    set: { _ in appState.toggleVisibility(item) }
                )) {
                    Image(systemName: item.isVisible ? "eye" : "eye.slash")
                }
                .toggleStyle(.button)
                .buttonStyle(.borderless)
                .help(item.isVisible ? "Hide" : "Show")

                // Toggle lock
                Toggle(isOn: Binding(
                    get: { item.isLocked },
                    set: { _ in appState.toggleLock(item) }
                )) {
                    Image(systemName: item.isLocked ? "lock.fill" : "lock.open")
                }
                .toggleStyle(.button)
                .buttonStyle(.borderless)
                .help(item.isLocked ? "Unlock" : "Lock")

                // Picker écran
                Picker("", selection: Binding(
                    get: { item.screenID },
                    set: { appState.setPinnedScreen(for: item, screenID: $0) }
                )) {
                    Text("No pin").tag(UInt32(0))
                    Divider()
                    ForEach(screens, id: \.displayID) { screen in
                        Text(screen.localizedName).tag(screen.displayID)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)

                // Indicateur connexion écran
                if item.screenID != 0 {
                    let connected = screens.contains { $0.displayID == item.screenID }
                    Image(systemName: connected
                          ? "checkmark.circle.fill"
                          : "exclamationmark.circle.fill")
                        .foregroundStyle(connected ? .green : .orange)
                        .help(connected
                              ? "Screen connected"
                              : "Screen not connected — GIF is hidden")
                }

                // Bouton Reset
                Button {
                    appState.resetWindow(item)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .help("Reset window")

                // Bouton Remove
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash").foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .help("Remove GIF")
            }

            // ── Ligne 2 : slider vitesse (E2) ────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: "speedometer")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Slider(
                    value: Binding(
                        get: { item.playbackSpeed },
                        set: { appState.setPlaybackSpeed(for: item, speed: $0) }
                    ),
                    in: 0.25...4.0,
                    step: 0.25
                )
                .frame(maxWidth: 200)

                Text(speedLabel(item.playbackSpeed))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: – Onglet Groups (étendu E1)

private struct GroupsSettingsTab: View {
    @EnvironmentObject var appState: AppState

    @State private var newGroupName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Barre : créer un groupe (TextField inline) ───────────────
            HStack(spacing: 8) {
                TextField("New group name…", text: $newGroupName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { commitNewGroup() }

                Button("Add") { commitNewGroup() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.bottom, 10)

            // ── Liste groupes ────────────────────────────────────────────
            if appState.groups.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                        Text("No groups yet")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                        Text("Type a name above and click \"Add\" to create a group.")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                List {
                    ForEach(appState.groups) { group in
                        GroupSettingsRow(group: group)
                            .environmentObject(appState)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .padding()
    }

    private func commitNewGroup() {
        let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        appState.createGroup(name: name)
        newGroupName = ""
    }
}

// MARK: – Ligne groupe expandable

private struct GroupSettingsRow: View {
    @EnvironmentObject var appState: AppState
    let group: GIFGroup

    @State private var isExpanded = false
    @State private var isEditing  = false
    @State private var editName   = ""
    @State private var showDeleteGroupAlert = false
    @State private var showDeleteAllAlert   = false

    private var isVisible: Bool { appState.groupIsVisible(group) }
    private var isLocked:  Bool { appState.groupIsLocked(group)  }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── En-tête ──────────────────────────────────────────────────
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .frame(width: 14)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)

                if isEditing {
                    TextField("Group name", text: $editName, onCommit: commitEdit)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                        .onExitCommand { cancelEdit() }
                } else {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(group.name)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text("\(group.gifIDs.count) GIF\(group.gifIDs.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()

                if isEditing {
                    Button("Save")   { commitEdit()  }.buttonStyle(.borderedProminent).controlSize(.small)
                    Button("Cancel") { cancelEdit()  }.controlSize(.small)
                } else {
                    Button {
                        editName  = group.name
                        isEditing = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .help("Rename group")

                    Button(role: .destructive) {
                        showDeleteGroupAlert = true
                    } label: {
                        Image(systemName: "trash").foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("Delete group (keep GIFs)")
                }
            }
            .padding(.vertical, 6)

            // ── Panneau expandable ───────────────────────────────────────
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()

                    // ── Contrôles de groupe (E1) ──────────────────────────
                    GroupQuickControls(group: group)
                        .environmentObject(appState)

                    Divider()

                    GroupMembersSection(group: group)
                        .environmentObject(appState)

                    Divider()

                    GroupScheduleSection(group: group)
                        .environmentObject(appState)

                    Divider()

                    GroupScreenPinSection(group: group)
                        .environmentObject(appState)
                }
                .padding(.leading, 22)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        // Alert : supprimer groupe (garder GIFs)
        .alert("Delete group \(group.name)?", isPresented: $showDeleteGroupAlert) {
            Button("Delete group", role: .destructive) { appState.deleteGroup(group) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The group will be deleted. Its GIFs will remain on the desktop.")
        }
        // Alert : supprimer groupe ET tous ses GIFs
        .alert("Delete group and all GIFs?", isPresented: $showDeleteAllAlert) {
            Button("Delete all", role: .destructive) { appState.removeGroup(group) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The group and all \(group.gifIDs.count) of its GIFs will be permanently removed. This cannot be undone.")
        }
    }

    private func commitEdit() {
        let t = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { appState.renameGroup(group, to: t) }
        isEditing = false
    }
    private func cancelEdit() { isEditing = false }
}

// MARK: – Contrôles rapides de groupe (E1)

private struct GroupQuickControls: View {
    @EnvironmentObject var appState: AppState
    let group: GIFGroup

    @State private var showDeleteAllAlert = false

    private var isVisible: Bool { appState.groupIsVisible(group) }
    private var isLocked:  Bool { appState.groupIsLocked(group)  }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Group controls", systemImage: "slider.horizontal.3")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 10) {
                // Toggle visibilité groupe
                Button {
                    appState.toggleGroupVisibility(group)
                } label: {
                    Label(isVisible ? "Hide all" : "Show all",
                          systemImage: isVisible ? "eye.slash" : "eye")
                }
                .controlSize(.small)

                // Toggle lock groupe
                Button {
                    appState.toggleGroupLock(group)
                } label: {
                    Label(isLocked ? "Unlock all" : "Lock all",
                          systemImage: isLocked ? "lock.open" : "lock")
                }
                .controlSize(.small)

                // Reset windows groupe
                Button {
                    appState.resetGroupWindows(group)
                } label: {
                    Label("Reset windows", systemImage: "arrow.counterclockwise")
                }
                .controlSize(.small)

                Spacer()

                // Supprimer groupe ET GIFs (destructif)
                Button(role: .destructive) {
                    showDeleteAllAlert = true
                } label: {
                    Label("Delete group and all GIFs", systemImage: "trash.fill")
                        .foregroundStyle(.red)
                }
                .controlSize(.small)
            }
        }
        .alert("Delete group and all GIFs?", isPresented: $showDeleteAllAlert) {
            Button("Delete all", role: .destructive) { appState.removeGroup(group) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The group and all \(group.gifIDs.count) of its GIFs will be permanently removed.")
        }
    }
}

// MARK: – Section membres

private struct GroupMembersSection: View {
    @EnvironmentObject var appState: AppState
    let group: GIFGroup

    private var memberGIFs: [GIFItem] {
        group.gifIDs.compactMap { id in appState.gifs.first { $0.id == id } }
    }

    private var ungroupedGIFs: [GIFItem] {
        let allGrouped = Set(appState.groups.flatMap { $0.gifIDs })
        return appState.gifs.filter { !allGrouped.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Members", systemImage: "photo.stack")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if memberGIFs.isEmpty {
                Text("No GIFs in this group.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 2)
            } else {
                ForEach(memberGIFs) { item in
                    HStack {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Text(item.label)
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button {
                            appState.removeGIF(item, from: group)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                        .help("Remove from group")
                    }
                    .padding(.vertical, 1)
                }
            }

            if !ungroupedGIFs.isEmpty {
                Menu {
                    ForEach(ungroupedGIFs) { item in
                        Button(item.label) {
                            appState.addGIF(item, to: group)
                        }
                    }
                } label: {
                    Label("Add GIF…", systemImage: "plus.circle")
                        .font(.callout)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }
}

// MARK: – Section plage horaire

private struct GroupScheduleSection: View {
    @EnvironmentObject var appState: AppState
    let group: GIFGroup

    @State private var scheduleEnabled = false
    @State private var startDate: Date = Self.defaultStart()
    @State private var endDate:   Date = Self.defaultEnd()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("Scheduled visibility", isOn: $scheduleEnabled)
                    .onChange(of: scheduleEnabled) { _, enabled in
                        commitSchedule(enabled: enabled)
                    }

                Spacer()

                if scheduleEnabled {
                    let inRange = group.isCurrentlyInSchedule()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(inRange ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)
                        Text(inRange ? "Active now" : "Inactive now")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if scheduleEnabled {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("From").font(.caption).foregroundStyle(.secondary)
                        DatePicker("", selection: $startDate, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .onChange(of: startDate) { _, _ in commitSchedule(enabled: true) }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("To").font(.caption).foregroundStyle(.secondary)
                        DatePicker("", selection: $endDate, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .onChange(of: endDate) { _, _ in commitSchedule(enabled: true) }
                    }
                    Spacer()
                }

                if crossesMidnight {
                    Label("This schedule spans midnight.", systemImage: "moon.stars")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear { loadFromGroup() }
        .onChange(of: group.scheduleStart) { _, _ in loadFromGroup() }
        .onChange(of: group.scheduleEnd)   { _, _ in loadFromGroup() }
    }

    private var crossesMidnight: Bool {
        let cal = Calendar.current
        let s = cal.component(.hour, from: startDate) * 60 + cal.component(.minute, from: startDate)
        let e = cal.component(.hour, from: endDate)   * 60 + cal.component(.minute, from: endDate)
        return s > e
    }

    private func loadFromGroup() {
        scheduleEnabled = group.scheduleStart != nil && group.scheduleEnd != nil
        let cal = Calendar.current
        if let s = group.scheduleStart, let sh = s.hour, let sm = s.minute {
            startDate = cal.date(bySettingHour: sh, minute: sm, second: 0, of: Date()) ?? startDate
        }
        if let e = group.scheduleEnd, let eh = e.hour, let em = e.minute {
            endDate = cal.date(bySettingHour: eh, minute: em, second: 0, of: Date()) ?? endDate
        }
    }

    private func commitSchedule(enabled: Bool) {
        guard enabled else {
            appState.setGroupSchedule(group, start: nil, end: nil)
            return
        }
        let cal = Calendar.current
        var start = DateComponents()
        start.hour   = cal.component(.hour,   from: startDate)
        start.minute = cal.component(.minute, from: startDate)
        var end = DateComponents()
        end.hour   = cal.component(.hour,   from: endDate)
        end.minute = cal.component(.minute, from: endDate)
        appState.setGroupSchedule(group, start: start, end: end)
    }

    private static func defaultStart() -> Date {
        Calendar.current.date(bySettingHour: 9,  minute: 0, second: 0, of: Date()) ?? Date()
    }
    private static func defaultEnd() -> Date {
        Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
    }
}

// MARK: – Section ancrage écran du groupe

private struct GroupScreenPinSection: View {
    @EnvironmentObject var appState: AppState
    let group: GIFGroup

    private var screens: [NSScreen] { NSScreen.screens }
    private var selectedScreenID: UInt32 { group.pinnedScreenID ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Group screen pinning", systemImage: "display")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text("Forces all members to the selected screen, overriding individual settings.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack(spacing: 8) {
                Picker("Screen", selection: Binding(
                    get: { selectedScreenID },
                    set: { newID in
                        appState.setGroupPinnedScreen(group, screenID: newID == 0 ? nil : newID)
                    }
                )) {
                    Text("No group pinning").tag(UInt32(0))
                    Divider()
                    ForEach(screens, id: \.displayID) { screen in
                        Text(screen.localizedName).tag(screen.displayID)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 240)

                if let sid = group.pinnedScreenID, sid != 0 {
                    let connected = screens.contains { $0.displayID == sid }
                    Image(systemName: connected
                          ? "checkmark.circle.fill"
                          : "exclamationmark.circle.fill")
                        .foregroundStyle(connected ? .green : .orange)
                        .help(connected
                              ? "Screen connected"
                              : "Screen not connected — group GIFs are hidden")
                }

                Spacer()
            }
        }
    }
}

// MARK: – Onglet General (inchangé + E4 option autoRename)

private struct GeneralSettingsTab: View {
    @State private var launchAtLogin: Bool = {
        if #available(macOS 13, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }()

    @AppStorage("autoRenameDuplicates") private var autoRenameDuplicates: Bool = true

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        if #available(macOS 13, *) {
                            do {
                                if newValue { try SMAppService.mainApp.register()   }
                                else        { try SMAppService.mainApp.unregister() }
                            } catch {
                                print("SMAppService error: \(error)")
                            }
                        }
                    }
            }

            Section("GIF import") {
                Toggle("Auto-rename duplicate GIFs", isOn: $autoRenameDuplicates)
                Text("When the same file is added more than once, a suffix (- 2, - 3…) is appended to the display name.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: – Onglet Credits (E3)

private struct CreditsTab: View {

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build  = Bundle.main.infoDictionary?["CFBundleVersion"]           as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 24) {

                // ── App identity ──────────────────────────────────────────
                VStack(spacing: 6) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)

                    Text("Desktop GIF")
                        .font(.title2.bold())

                    Text("Version \(appVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Made by Gigi ★")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Link("View source on GitHub",
                         destination: URL(string: "https://github.com")!)
                        .font(.callout)
                }

                Divider()

                // ── Open Source ───────────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("Open Source")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("No third-party dependencies.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Text("Desktop GIF is built exclusively with Apple frameworks: SwiftUI, AppKit, ImageIO, and CoreGraphics.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                // ── License ───────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("License")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("MIT License")
                        .font(.callout.bold())

                    Text("Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the \"Software\"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(24)
        }
    }
}
