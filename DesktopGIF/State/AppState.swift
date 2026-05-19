// AppState.swift — Étape E

import Foundation
import AppKit
import Combine

final class AppState: ObservableObject {
    @Published var gifs:   [GIFItem]  = []
    @Published var groups: [GIFGroup] = []

    let windowManager = DesktopWindowManager()
    private let legacyKey = "savedGIFs"

    private var scheduleTimer: Timer?

    init() {
        load()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            for item in self.gifs {
                if item.isVisible {
                    self.windowManager.openWindow(for: item)
                } else {
                    self.windowManager.registerWithoutOpening(for: item)
                }
                self.injectContextMenu(for: item)
            }
            self.applySchedules()
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(handleMove(_:)),
            name: .gifDidMove, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleResize(_:)),
            name: .gifDidResize, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleMoveEnded(_:)),
            name: .gifDidMoveEnded, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleResizeEnded(_:)),
            name: .gifDidResizeEnded, object: nil)

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleOtherAppActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSpaceChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil)

        startScheduleTimer()
    }

    deinit {
        scheduleTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    // MARK: – Schedule timer

    private func startScheduleTimer() {
        scheduleTimer?.invalidate()
        scheduleTimer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            self?.applySchedules()
        }
        RunLoop.main.add(scheduleTimer!, forMode: .common)
    }

    func applySchedules() {
        var changed = false
        for group in groups {
            guard group.scheduleStart != nil && group.scheduleEnd != nil else { continue }
            let shouldBeVisible = group.isCurrentlyInSchedule()
            guard shouldBeVisible != groupIsVisible(group) else { continue }
            setGroupVisibility(group, visible: shouldBeVisible)
            changed = true
        }
        if changed { save() }
    }

    private func setGroupVisibility(_ group: GIFGroup, visible: Bool) {
        group.gifIDs.forEach { id in
            guard let idx = gifs.firstIndex(where: { $0.id == id }) else { return }
            gifs[idx].isVisible = visible
            windowManager.updateVisibility(for: id, visible: visible)
        }
    }

    // MARK: – GIF CRUD

    func addGIF(at path: String) {
        var item = GIFItem(filePath: path)

        // Étape E4 : déduplication automatique si l'option est activée
        let autoRename = UserDefaults.standard.object(forKey: "autoRenameDuplicates") as? Bool ?? true
        if autoRename {
            let base = URL(fileURLWithPath: path).lastPathComponent
            let duplicateCount = gifs.filter { $0.filePath == path }.count
            if duplicateCount > 0 {
                item.displayName = "\(base) - \(duplicateCount + 1)"
            }
        }

        gifs.append(item)
        windowManager.openWindow(for: item)
        injectContextMenu(for: item)
        save()
    }

    func remove(_ item: GIFItem) {
        windowManager.closeWindow(for: item.id)
        gifs.removeAll { $0.id == item.id }
        for idx in groups.indices {
            groups[idx].gifIDs.removeAll { $0 == item.id }
        }
        save()
    }

    func toggleLock(_ item: GIFItem) {
        guard let idx = gifs.firstIndex(where: { $0.id == item.id }) else { return }
        gifs[idx].isLocked.toggle()
        windowManager.updateLock(for: item.id, locked: gifs[idx].isLocked)
        save()
    }

    func toggleVisibility(_ item: GIFItem) {
        guard let idx = gifs.firstIndex(where: { $0.id == item.id }) else { return }
        gifs[idx].isVisible.toggle()
        windowManager.updateVisibility(for: item.id, visible: gifs[idx].isVisible)
        save()
    }

    func resetWindow(_ item: GIFItem) {
        windowManager.resetWindow(for: item.id)
    }

    func resetAllWindows() {
        gifs.filter { $0.isVisible }.forEach { windowManager.resetWindow(for: $0.id) }
    }

    // MARK: – Étape E2 : vitesse de lecture

    func setPlaybackSpeed(for item: GIFItem, speed: Double) {
        guard let idx = gifs.firstIndex(where: { $0.id == item.id }) else { return }
        gifs[idx].playbackSpeed = speed
        windowManager.setPlaybackSpeed(for: item.id, speed: speed)
        save()
    }

    // MARK: – Screen pinning individuel

    func setPinnedScreen(for item: GIFItem, screenID: UInt32) {
        guard let idx = gifs.firstIndex(where: { $0.id == item.id }) else { return }
        gifs[idx].screenID = screenID
        if screenID != 0, let screen = nsScreen(for: screenID) {
            let origin = NSPoint(x: gifs[idx].positionX, y: gifs[idx].positionY)
            gifs[idx].screenRelativeX = Double(origin.x - screen.frame.origin.x)
            gifs[idx].screenRelativeY = Double(origin.y - screen.frame.origin.y)
        }
        windowManager.updatePinnedScreen(for: gifs[idx])
        save()
    }

    // MARK: – Group management

    func createGroup(name: String, gifIDs: [UUID] = []) {
        groups.append(GIFGroup(name: name, gifIDs: gifIDs))
        save()
    }

    func renameGroup(_ group: GIFGroup, to name: String) {
        guard let idx = groups.firstIndex(where: { $0.id == group.id }) else { return }
        groups[idx].name = name
        save()
    }

    func deleteGroup(_ group: GIFGroup) {
        groups.removeAll { $0.id == group.id }
        save()
    }

    func addGIF(_ item: GIFItem, to group: GIFGroup) {
        guard let idx = groups.firstIndex(where: { $0.id == group.id }) else { return }
        guard !groups[idx].gifIDs.contains(item.id) else { return }
        groups[idx].gifIDs.append(item.id)
        if let screenID = groups[idx].pinnedScreenID {
            applyScreenPinning(gifID: item.id, screenID: screenID)
        }
        save()
    }

    func removeGIF(_ item: GIFItem, from group: GIFGroup) {
        guard let idx = groups.firstIndex(where: { $0.id == group.id }) else { return }
        groups[idx].gifIDs.removeAll { $0 == item.id }
        save()
    }

    func toggleGroupVisibility(_ group: GIFGroup) {
        let members = group.gifIDs.compactMap { id in gifs.first { $0.id == id } }
        let target  = !members.contains { $0.isVisible }
        members.forEach { item in
            guard let idx = gifs.firstIndex(where: { $0.id == item.id }) else { return }
            gifs[idx].isVisible = target
            windowManager.updateVisibility(for: item.id, visible: target)
        }
        save()
    }

    func groupIsVisible(_ group: GIFGroup) -> Bool {
        group.gifIDs.contains { id in gifs.first { $0.id == id }?.isVisible == true }
    }

    func groupIsLocked(_ group: GIFGroup) -> Bool {
        group.gifIDs.contains { id in gifs.first { $0.id == id }?.isLocked == true }
    }

    func toggleGroupLock(_ group: GIFGroup) {
        let members = group.gifIDs.compactMap { id in gifs.first { $0.id == id } }
        let target  = members.contains { !$0.isLocked }
        members.forEach { item in
            guard let idx = gifs.firstIndex(where: { $0.id == item.id }) else { return }
            gifs[idx].isLocked = target
            windowManager.updateLock(for: item.id, locked: target)
        }
        save()
    }

    func resetGroupWindows(_ group: GIFGroup) {
        group.gifIDs.forEach { id in
            if let item = gifs.first(where: { $0.id == id }), item.isVisible {
                windowManager.resetWindow(for: id)
            }
        }
    }

    func removeGroup(_ group: GIFGroup) {
        group.gifIDs.forEach { id in
            windowManager.closeWindow(for: id)
            gifs.removeAll { $0.id == id }
            for idx in groups.indices { groups[idx].gifIDs.removeAll { $0 == id } }
        }
        groups.removeAll { $0.id == group.id }
        save()
    }

    // MARK: – Étape C : plage horaire / ancrage écran par groupe

    func setGroupSchedule(_ group: GIFGroup, start: DateComponents?, end: DateComponents?) {
        guard let idx = groups.firstIndex(where: { $0.id == group.id }) else { return }
        groups[idx].scheduleStart = start
        groups[idx].scheduleEnd   = end
        save()
        applySchedules()
    }

    func setGroupPinnedScreen(_ group: GIFGroup, screenID: UInt32?) {
        guard let idx = groups.firstIndex(where: { $0.id == group.id }) else { return }
        groups[idx].pinnedScreenID = screenID
        if let sid = screenID { applyScreenPinningToGroup(groups[idx], screenID: sid) }
        save()
    }

    private func applyScreenPinningToGroup(_ group: GIFGroup, screenID: UInt32) {
        group.gifIDs.forEach { applyScreenPinning(gifID: $0, screenID: screenID) }
    }

    private func applyScreenPinning(gifID: UUID, screenID: UInt32) {
        guard let idx = gifs.firstIndex(where: { $0.id == gifID }) else { return }
        gifs[idx].screenID = screenID
        if screenID != 0, let screen = nsScreen(for: screenID) {
            let origin = NSPoint(x: gifs[idx].positionX, y: gifs[idx].positionY)
            gifs[idx].screenRelativeX = Double(origin.x - screen.frame.origin.x)
            gifs[idx].screenRelativeY = Double(origin.y - screen.frame.origin.y)
        }
        windowManager.updatePinnedScreen(for: gifs[idx])
    }

    // MARK: – Context menu

    private func injectContextMenu(for item: GIFItem) {
        let id = item.id
        windowManager.setContextMenuBuilder(for: id) { [weak self] in
            self?.buildContextMenu(for: id)
        }
    }

    private func buildContextMenu(for id: UUID) -> NSMenu? {
        guard let item = gifs.first(where: { $0.id == id }) else { return nil }
        let name = item.label
        let menu = NSMenu(title: name)
        let title = NSMenuItem(title: name, action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())
        menu.addItem(makeItem(title: item.isLocked  ? "Unlock" : "Lock",
                              icon:  item.isLocked  ? "lock.open" : "lock",
                              action: #selector(contextToggleLock(_:)), id: id))
        menu.addItem(makeItem(title: item.isVisible ? "Hide" : "Show",
                              icon:  item.isVisible ? "eye.slash" : "eye",
                              action: #selector(contextToggleVisibility(_:)), id: id))
        menu.addItem(makeItem(title: "Reset window", icon: "arrow.counterclockwise",
                              action: #selector(contextResetWindow(_:)), id: id))
        menu.addItem(.separator())
        menu.addItem(makeItem(title: "Remove", icon: "trash",
                              action: #selector(contextRemove(_:)), id: id))
        return menu
    }

    private func makeItem(title: String, icon: String,
                          action: Selector, id: UUID) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        item.representedObject = id
        item.target = self
        return item
    }

    @objc private func contextToggleLock(_ s: NSMenuItem) {
        guard let id = s.representedObject as? UUID,
              let item = gifs.first(where: { $0.id == id }) else { return }
        toggleLock(item)
    }
    @objc private func contextToggleVisibility(_ s: NSMenuItem) {
        guard let id = s.representedObject as? UUID,
              let item = gifs.first(where: { $0.id == id }) else { return }
        toggleVisibility(item)
    }
    @objc private func contextResetWindow(_ s: NSMenuItem) {
        guard let id = s.representedObject as? UUID,
              let item = gifs.first(where: { $0.id == id }) else { return }
        resetWindow(item)
    }
    @objc private func contextRemove(_ s: NSMenuItem) {
        guard let id = s.representedObject as? UUID,
              let item = gifs.first(where: { $0.id == id }) else { return }
        remove(item)
    }

    // MARK: – Focus-loss / space / screen

    @objc private func handleOtherAppActivated(_ n: Notification) { reorderVisibleWindows() }
    @objc private func handleSpaceChange()                        { reorderVisibleWindows() }

    @objc private func handleScreenParametersChange() {
        windowManager.applyScreenAvailability(for: gifs)
        reorderVisibleWindows()
    }

    private func reorderVisibleWindows() {
        let ids = Set(gifs.filter { $0.isVisible && !$0.isLocked }.map { $0.id })
        windowManager.reorderAllVisible(visibleIDs: ids)
    }

    // MARK: – Notification handlers

    @objc private func handleMove(_ n: Notification) {
        guard let info = n.userInfo,
              let id  = info["id"] as? UUID,
              let x   = info["x"] as? Double,
              let y   = info["y"] as? Double,
              let idx = gifs.firstIndex(where: { $0.id == id }) else { return }
        gifs[idx].positionX = x
        gifs[idx].positionY = y
    }

    @objc private func handleResize(_ n: Notification) {
        guard let info = n.userInfo,
              let id  = info["id"] as? UUID,
              let w   = info["w"] as? Double,
              let h   = info["h"] as? Double,
              let idx = gifs.firstIndex(where: { $0.id == id }) else { return }
        gifs[idx].width  = w
        gifs[idx].height = h
    }

    @objc private func handleMoveEnded(_ n: Notification) {
        guard let info = n.userInfo,
              let id  = info["id"] as? UUID,
              let x   = info["x"] as? Double,
              let y   = info["y"] as? Double,
              let idx = gifs.firstIndex(where: { $0.id == id }) else { return }
        gifs[idx].positionX = x
        gifs[idx].positionY = y
        if let relX = info["screenRelX"] as? Double,
           let relY = info["screenRelY"] as? Double {
            gifs[idx].screenRelativeX = relX
            gifs[idx].screenRelativeY = relY
        }
        save()
    }

    @objc private func handleResizeEnded(_ n: Notification) {
        guard let info = n.userInfo,
              let id  = info["id"] as? UUID,
              let w   = info["w"] as? Double,
              let h   = info["h"] as? Double,
              let idx = gifs.firstIndex(where: { $0.id == id }) else { return }
        gifs[idx].width  = w
        gifs[idx].height = h
        save()
    }

    // MARK: – Persistence

    func save() {
        do {
            try PersistenceManager.save(AppPersistedState(gifs: gifs, groups: groups))
        } catch {
            print("AppState: save failed — \(error)")
        }
    }

    private func load() {
        if let state = try? PersistenceManager.load() {
            gifs   = state.gifs
            groups = state.groups
            return
        }
        if let data  = UserDefaults.standard.data(forKey: legacyKey),
           let items = try? JSONDecoder().decode([GIFItem].self, from: data) {
            gifs   = items
            groups = []
            save()
            UserDefaults.standard.removeObject(forKey: legacyKey)
            print("AppState: migrated \(items.count) GIF(s) from UserDefaults.")
            return
        }
        gifs   = []
        groups = []
    }
}
