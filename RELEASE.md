# Release v1.0.0 — Desktop GIF

> **First public release.**

---

## What's new

### Core features
- Display animated GIFs directly on the macOS desktop, below all windows, on the wallpaper layer.
- Drag and resize GIFs freely; a resize handle sits in the bottom-right corner of each GIF.
- Lock a GIF in place (ignores mouse events) or hide it without removing it from the library.

### Screen pinning
- Pin any GIF to a specific display. It hides automatically when that display is disconnected and reappears when it reconnects.
- Relative position to the pinned screen is preserved across reconnections.

### Groups & schedules
- Organise GIFs into named groups.
- Control visibility, lock state, and screen pinning for an entire group at once.
- Set a daily time range for a group — Desktop GIF shows and hides it automatically. Time ranges that cross midnight are supported.

### Playback speed
- Per-GIF speed multiplier from 0.25× to 4×.
- Adjusted live — no frame reload, no stutter.

### Smart duplicate handling
- Importing the same file twice auto-suffixes the display name (` - 2`, ` - 3`…). The file path is unchanged.
- Can be disabled in Settings → General.

### Settings window
- **GIFs tab** — full per-GIF control: visibility, lock, screen pin, playback speed, remove.
- **Groups tab** — create groups inline, manage members, configure schedules and screen pinning.
- **General tab** — launch at login, duplicate rename toggle.
- **Credits tab** — version info, license.

### Menu bar
- Minimal footprint: *Add a GIF…*, *Settings…*, *Quit*. No Dock icon (`LSUIElement`).

---

## Requirements

- **macOS Sonoma 14.0 or later**
- Apple Silicon or Intel

---

## Installation

1. Download `DesktopGIF.dmg` below.
2. Open the DMG and drag **Desktop GIF.app** to `/Applications`.
3. Launch the app — approve the security prompt on first open if needed.

---

## Known limitations

- GIFs with hundreds of frames and very high resolutions consume significant RAM while visible (frames are held decoded in memory for smooth playback). Hidden GIFs use zero memory.
- No support for WebP or APNG in this release.

---

*Made by Gigi ✦*

---
