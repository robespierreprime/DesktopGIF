// DesktopWindowManager.swift — Étape E2

import AppKit

final class DesktopWindowManager {
    private var controllers: [UUID: GIFWindowController] = [:]

    // MARK: – Position resolution

    private func resolvedOrigin(for item: GIFItem) -> NSPoint? {
        guard item.screenID != 0 else {
            return NSPoint(x: item.positionX, y: item.positionY)
        }
        guard let screen = nsScreen(for: item.screenID) else { return nil }
        return NSPoint(
            x: screen.frame.origin.x + item.screenRelativeX,
            y: screen.frame.origin.y + item.screenRelativeY)
    }

    // MARK: – Ouverture normale (GIF visible au démarrage)

    func openWindow(for item: GIFItem) {
        guard controllers[item.id] == nil else { return }

        var placed = item
        if let origin = resolvedOrigin(for: item) {
            placed.positionX = origin.x
            placed.positionY = origin.y
        }

        let controller = GIFWindowController(item: placed)
        controllers[item.id] = controller

        if resolvedOrigin(for: item) != nil {
            controller.resumeRendering()
            controller.window?.orderFront(nil)
        }
    }

    // MARK: – Étape D : enregistrement différé (GIF masqué au démarrage)

    func registerWithoutOpening(for item: GIFItem) {
        guard controllers[item.id] == nil else { return }

        var placed = item
        if let origin = resolvedOrigin(for: item) {
            placed.positionX = origin.x
            placed.positionY = origin.y
        }

        let controller = GIFWindowController(item: placed)
        controllers[item.id] = controller
    }

    func closeWindow(for id: UUID) {
        controllers[id]?.pauseRendering()
        controllers[id]?.window?.orderOut(nil)
        controllers[id]?.window?.close()
        controllers.removeValue(forKey: id)
    }

    func updateLock(for id: UUID, locked: Bool) {
        controllers[id]?.setLocked(locked)
    }

    // MARK: – Étape D : visibilité avec pause / resume

    func updateVisibility(for id: UUID, visible: Bool) {
        guard let controller = controllers[id] else { return }
        if visible {
            controller.resumeRendering()
            controller.window?.orderFront(nil)
        } else {
            controller.window?.orderOut(nil)
            controller.pauseRendering()
        }
    }

    func resetWindow(for id: UUID) {
        guard let controller = controllers[id] else { return }
        controller.setLocked(false)   // unlocks + restores resize handle
        controller.window?.orderOut(nil)
        controller.resumeRendering()
        controller.window?.orderFront(nil)
    }

    func reorderAllVisible(visibleIDs: Set<UUID>) {
        for id in visibleIDs {
            guard let win = controllers[id]?.window else { continue }
            win.orderOut(nil)
            win.orderFront(nil)
        }
    }

    // MARK: – Screen connect / disconnect

    func applyScreenAvailability(for items: [GIFItem]) {
        for item in items {
            guard item.screenID != 0, item.isVisible else { continue }
            guard let controller = controllers[item.id] else { continue }
            let win = controller.window

            if let screen = nsScreen(for: item.screenID) {
                let origin = NSPoint(
                    x: screen.frame.origin.x + item.screenRelativeX,
                    y: screen.frame.origin.y + item.screenRelativeY)
                win?.setFrameOrigin(origin)
                controller.resumeRendering()
                win?.orderFront(nil)
            } else {
                win?.orderOut(nil)
                controller.pauseRendering()
            }
        }
    }

    // MARK: – Settings : mise à jour screenID

    func updatePinnedScreen(for item: GIFItem) {
        controllers[item.id]?.updatePinnedScreen(item.screenID)
        guard item.isVisible else { return }
        if item.screenID == 0 {
            controllers[item.id]?.resumeRendering()
            controllers[item.id]?.window?.orderFront(nil)
        } else if let screen = nsScreen(for: item.screenID) {
            let origin = NSPoint(
                x: screen.frame.origin.x + item.screenRelativeX,
                y: screen.frame.origin.y + item.screenRelativeY)
            controllers[item.id]?.window?.setFrameOrigin(origin)
            controllers[item.id]?.resumeRendering()
            controllers[item.id]?.window?.orderFront(nil)
        } else {
            controllers[item.id]?.window?.orderOut(nil)
            controllers[item.id]?.pauseRendering()
        }
    }

    // MARK: – Étape E2 : vitesse de lecture

    /// Applique le multiplicateur de vitesse à la fenêtre correspondante sans recharger les frames.
    func setPlaybackSpeed(for id: UUID, speed: Double) {
        controllers[id]?.setPlaybackSpeed(speed)
    }

    func setContextMenuBuilder(for id: UUID, builder: @escaping () -> NSMenu?) {
        controllers[id]?.contextMenuBuilder = builder
    }
}
