# Release v2.3.1 — Desktop GIF

> **Patch release — bug fixes.**

---

## Bug fixes & improvements

### Schedule now respects screen pinning
A scheduled group could previously make GIFs appear on screen even when their pinned display was disconnected. The schedule now checks display availability before showing any window — the intent is preserved in state, so GIFs surface automatically once the screen reconnects.

### Resize handle hidden while locked
The resize handle drawn in the bottom-right corner of each GIF is no longer visible when the GIF is locked. It reappears immediately on unlock or after "Reset window". The handle is also correctly hidden for GIFs that start in a locked state at launch.

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
- Drag may not respond after switching Space or unlocking → workaround: “Reset window” button

---

*Made by Gigi ✦*

---
