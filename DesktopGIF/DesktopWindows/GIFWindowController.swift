// DesktopWindows/GIFWindowController.swift — Étape E2

import AppKit
import SwiftUI

// MARK: – Notification names

extension Notification.Name {
    static let gifDidMove        = Notification.Name("gifDidMove")
    static let gifDidMoveEnded   = Notification.Name("gifDidMoveEnded")
    static let gifDidResize      = Notification.Name("gifDidResize")
    static let gifDidResizeEnded = Notification.Name("gifDidResizeEnded")
}

// MARK: – NSScreen helper

extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (deviceDescription[key] as? NSNumber)?.uint32Value ?? 0
    }
}

func nsScreen(for displayID: CGDirectDisplayID) -> NSScreen? {
    guard displayID != 0 else { return nil }
    return NSScreen.screens.first { $0.displayID == displayID }
}

// MARK: – DraggableWindow

final class DraggableWindow: NSWindow {
    override var canBecomeKey:  Bool { false }
    override var canBecomeMain: Bool { false }
    override func makeKey() {}

    weak var containerView: DraggableContainerView?

    override func sendEvent(_ event: NSEvent) {
        guard let container = containerView else { super.sendEvent(event); return }
        switch event.type {
        case .leftMouseDown:    container.handleMouseDown(event)
        case .leftMouseDragged: container.handleMouseDragged(event)
        case .leftMouseUp:      container.handleMouseUp(event)
        case .rightMouseDown:   container.handleRightMouseDown(event)
        default:                super.sendEvent(event)
        }
    }
}

// MARK: – DraggableContainerView

final class DraggableContainerView: NSView {

    var onDragBegan:   ((NSPoint) -> Void)?
    var onDragMoved:   ((NSPoint) -> Void)?
    var onDragEnded:   (() -> Void)?
    var onResizeBegan: ((NSPoint) -> Void)?
    var onResizeMoved: ((NSPoint) -> Void)?
    var onResizeEnded: (() -> Void)?
    var contextMenuProvider: (() -> NSMenu?)?

    /// Controls whether the resize handle is drawn. Mirrors the window lock state.
    var isLocked: Bool = false {
        didSet { needsDisplay = true }
    }

    private enum InteractionMode { case none, dragging, resizing }
    private var mode: InteractionMode = .none
    private let handleSize: CGFloat = 16

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }
    override var acceptsFirstResponder: Bool { true }

    func handleMouseDown(_ event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        let handleRect = NSRect(x: bounds.maxX - handleSize, y: bounds.minY,
                                width: handleSize, height: handleSize)
        if handleRect.contains(local) { mode = .resizing; onResizeBegan?(NSEvent.mouseLocation) }
        else                          { mode = .dragging;  onDragBegan?(NSEvent.mouseLocation)  }
    }

    func handleMouseDragged(_ event: NSEvent) {
        switch mode {
        case .dragging:  onDragMoved?(NSEvent.mouseLocation)
        case .resizing:  onResizeMoved?(NSEvent.mouseLocation)
        case .none:      break
        }
    }

    func handleMouseUp(_ event: NSEvent) {
        switch mode {
        case .dragging:  onDragEnded?()
        case .resizing:  onResizeEnded?()
        case .none:      break
        }
        mode = .none
    }

    func handleRightMouseDown(_ event: NSEvent) {
        if let menu = contextMenuProvider?() {
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }
    }

    func cancelInteraction() {
        switch mode {
        case .dragging:  onDragEnded?()
        case .resizing:  onResizeEnded?()
        case .none:      break
        }
        mode = .none
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !isLocked else { return }   // hide handle when locked
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.5).cgColor)
        ctx.setLineWidth(1.5)
        let margin: CGFloat = 3
        let x = bounds.maxX - margin
        let y = bounds.minY + margin
        for offset in stride(from: CGFloat(2), through: CGFloat(10), by: CGFloat(4)) {
            ctx.move(to: CGPoint(x: x - offset, y: y))
            ctx.addLine(to: CGPoint(x: x, y: y + offset))
        }
        ctx.strokePath()
    }

    override func scrollWheel(with event: NSEvent) { super.scrollWheel(with: event) }
}

// MARK: – GIFWindowController

final class GIFWindowController: NSWindowController {

    private let itemID:       UUID
    private var pinnedScreenID: CGDirectDisplayID

    private var dragOffset:   NSPoint = .zero
    private var resizeOrigin: NSPoint = .zero
    private var sizeAtResize: NSSize  = .zero

    private weak var containerView: DraggableContainerView?
    private weak var gifImageView: GIFImageView?

    private var spaceObserver: NSObjectProtocol?

    static let minSize = NSSize(width: 40, height: 40)

    var contextMenuBuilder: (() -> NSMenu?)?

    // MARK: – Init

    init(item: GIFItem) {
        self.itemID         = item.id
        self.pinnedScreenID = item.screenID

        let win = DraggableWindow(
            contentRect: item.frame,
            styleMask:   [.borderless],
            backing:     .buffered,
            defer:       false
        )
        win.isOpaque           = false
        win.backgroundColor    = .clear
        win.hasShadow          = false
        win.level              = .init(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)))
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]
        win.ignoresMouseEvents = item.isLocked

        let container = DraggableContainerView()
        container.wantsLayer             = true
        container.layer?.backgroundColor = CGColor.clear
        win.containerView = container

        let gifView = GIFImageView(fileURL: item.fileURL)
        gifView.playbackSpeed = item.playbackSpeed
        gifView.translatesAutoresizingMaskIntoConstraints = false
        gifView.wantsLayer = true
        container.addSubview(gifView)
        NSLayoutConstraint.activate([
            gifView.topAnchor.constraint(equalTo:      container.topAnchor),
            gifView.bottomAnchor.constraint(equalTo:   container.bottomAnchor),
            gifView.leadingAnchor.constraint(equalTo:  container.leadingAnchor),
            gifView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        win.contentView = container
        super.init(window: win)

        self.containerView = container
        self.gifImageView  = gifView

        // Sync initial lock state so the handle is hidden if the GIF starts locked.
        container.isLocked = item.isLocked

        container.contextMenuProvider = { [weak self] in self?.contextMenuBuilder?() }

        // MARK: Drag

        container.onDragBegan = { [weak self] screenPoint in
            guard let self, let win = self.window else { return }
            self.dragOffset = NSPoint(
                x: screenPoint.x - win.frame.origin.x,
                y: screenPoint.y - win.frame.origin.y)
        }

        container.onDragMoved = { [weak self] screenPoint in
            guard let self, let win = self.window else { return }
            let newOrigin = NSPoint(
                x: screenPoint.x - self.dragOffset.x,
                y: screenPoint.y - self.dragOffset.y)
            win.setFrameOrigin(newOrigin)
            NotificationCenter.default.post(
                name: .gifDidMove, object: nil,
                userInfo: ["id": self.itemID,
                           "x": Double(newOrigin.x),
                           "y": Double(newOrigin.y)])
        }

        container.onDragEnded = { [weak self] in
            guard let self, let win = self.window else { return }
            let origin = win.frame.origin
            var info: [String: Any] = [
                "id": self.itemID,
                "x":  Double(origin.x),
                "y":  Double(origin.y)]
            if self.pinnedScreenID != 0,
               let screen = nsScreen(for: self.pinnedScreenID) {
                info["screenRelX"] = Double(origin.x - screen.frame.origin.x)
                info["screenRelY"] = Double(origin.y - screen.frame.origin.y)
            }
            NotificationCenter.default.post(
                name: .gifDidMoveEnded, object: nil, userInfo: info)
        }

        // MARK: Resize

        container.onResizeBegan = { [weak self] screenPoint in
            guard let self, let win = self.window else { return }
            self.resizeOrigin = screenPoint
            self.sizeAtResize = win.frame.size
        }

        container.onResizeMoved = { [weak self] screenPoint in
            guard let self, let win = self.window else { return }
            let dx = screenPoint.x - self.resizeOrigin.x
            let dy = screenPoint.y - self.resizeOrigin.y
            let newWidth  = max(Self.minSize.width,  self.sizeAtResize.width  + dx)
            let newHeight = max(Self.minSize.height, self.sizeAtResize.height - dy)
            var frame = win.frame
            frame.origin.y = frame.origin.y + frame.size.height - newHeight
            frame.size     = NSSize(width: newWidth, height: newHeight)
            win.setFrame(frame, display: true, animate: false)
            NotificationCenter.default.post(
                name: .gifDidResize, object: nil,
                userInfo: ["id": self.itemID,
                           "w": Double(newWidth),
                           "h": Double(newHeight)])
        }

        container.onResizeEnded = { [weak self] in
            guard let self, let win = self.window else { return }
            let size = win.frame.size
            NotificationCenter.default.post(
                name: .gifDidResizeEnded, object: nil,
                userInfo: ["id": self.itemID,
                           "w": Double(size.width),
                           "h": Double(size.height)])
        }

        // MARK: Space change

        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.containerView?.cancelInteraction()
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        if let obs = spaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
    }

    // MARK: – Public API

    func setLocked(_ locked: Bool) {
        if !locked { containerView?.cancelInteraction() }
        containerView?.isLocked = locked
        window?.ignoresMouseEvents = locked
    }

    func updatePinnedScreen(_ screenID: CGDirectDisplayID) {
        self.pinnedScreenID = screenID
    }

    // MARK: – Étape D : gestion mémoire

    func resumeRendering() {
        gifImageView?.resume()
    }

    func pauseRendering() {
        gifImageView?.pause()
    }

    // MARK: – Étape E2 : vitesse de lecture

    /// Met à jour le multiplicateur de vitesse sans recharger les frames.
    func setPlaybackSpeed(_ speed: Double) {
        gifImageView?.setPlaybackSpeed(speed)
    }
}
