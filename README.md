# Desktop GIF

> Display animated GIFs directly on your macOS desktop — no clutter, no borders, just your GIFs living on the wallpaper.

![macOS](https://img.shields.io/badge/macOS-14%2B-blue?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift)
![License](https://img.shields.io/badge/license-GPL--v2-green)
![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)

---

## Features

- **Desktop-level windows** — GIFs render below all apps, pinned to the wallpaper layer.
- **Drag & resize** — move and resize any GIF directly on the desktop. A resize handle sits in the bottom-right corner.
- **Lock / hide** — lock a GIF in place to prevent accidental moves, or hide it without removing it.
- **Screen pinning** — pin a GIF to a specific display. It auto-hides when that display is disconnected and reappears when it reconnects.
- **Groups** — organise GIFs into named groups with shared visibility, lock state, screen pinning, and scheduled time ranges.
- **Scheduled visibility** — define a daily time range (supports midnight-crossing) during which a group is shown automatically.
- **Playback speed** — per-GIF speed multiplier from 0.25× to 4×, adjusted live without reloading frames.
- **Duplicate handling** — importing the same file twice auto-suffixes the display name (- 2, - 3…).
- **Minimal menu bar** — lives in the menu bar (`LSUIElement`), no Dock icon.
- **Zero dependencies** — built with SwiftUI, AppKit, ImageIO, and CoreGraphics only.
- **Persistent state** — layout, groups, and settings survive restarts via `~/Library/Application Support/DesktopGIF/state.json`.

---

## Requirements

| Requirement | Minimum |
|---|---|
| **macOS** | **Sonoma 14.0** |
| **Chip** | Apple Silicon or Intel (Universal Binary) |
| **Xcode** | 15.0+ (to build from source) |
| **Swift** | 5.9+ |

> **Why macOS 14 (Sonoma)?**
> The app relies on `MenuBarExtra` (introduced in macOS 13) and several SwiftUI APIs — notably `onChange(of:initial:_:)` with two-parameter closure syntax and `@Observable`-adjacent patterns — that require macOS 14. `SMAppService` for Launch at Login also requires macOS 13+.

---

## Installation

### Download (recommended)

1. Go to the [Releases](../../releases) page.
2. Download the latest `DesktopGIF.dmg`.
3. Open the DMG, drag **Desktop GIF.app** to `/Applications`.
4. On first launch, macOS may ask to confirm opening an app from the internet — click **Open**.

### Build from source

```bash
git clone https://github.com/yourname/DesktopGIF.git
cd DesktopGIF
open DesktopGIF.xcodeproj
```

Select the `DesktopGIF` scheme, choose **My Mac** as destination, then **Product → Run** (⌘R) or **Product → Archive** to produce a release build.

---

## Usage

After launch, a paintbrush icon appears in the menu bar.

- **Add a GIF** — click the menu bar icon → *Add a GIF…* (or ⌘O).
- **Move / resize** — click and drag any GIF on the desktop; drag the bottom-right corner to resize.
- **Settings** — ⌘, opens the Settings window with three tabs:
  - **GIFs** — visibility, lock, screen pinning, playback speed, remove.
  - **Groups** — create groups, set schedules, pin groups to screens.
  - **General** — launch at login, duplicate rename option.
- **Right-click** any GIF on the desktop for a quick context menu.

---

## Project structure

```
DesktopGIF/
├── App/
│   └── DesktopGIFApp.swift       # @main, MenuBarExtra + Settings scene
├── Models/
│   ├── GIFItem.swift             # Per-GIF model (Codable)
│   └── GIFGroup.swift            # Group model with schedule support
├── State/
│   └── AppState.swift            # Single source of truth, ObservableObject
├── Persistence/
│   └── PersistenceManager.swift  # JSON encode/decode to Application Support
├── DesktopWindows/
│   ├── GIFWindowController.swift # Borderless NSWindow, drag & resize
│   └── DesktopWindowManager.swift
├── GIFRenderer/
│   └── GIFRendererView.swift     # Frame-by-frame ImageIO playback
└── Views/
    ├── MenuBarView.swift
    └── SettingsView.swift
```

---

## License

MIT — see [LICENSE](LICENSE).

---

*Made with ★ by Gigi*
