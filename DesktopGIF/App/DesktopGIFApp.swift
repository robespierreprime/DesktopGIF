//
//  DesktopGIFApp.swift
//  Desktop GIF
//

import SwiftUI
import AppKit

@main
struct GIFDesktopApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Desktop GIFs", systemImage: "paintbrush.fill") {
            MenuBarView()
                .environmentObject(appState)
        }

        // Étape B — fenêtre Settings
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
