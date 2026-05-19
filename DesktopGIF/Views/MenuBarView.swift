// MenuBarView.swift — Étape E1 : MenuBar simplifié

import SwiftUI
internal import UniformTypeIdentifiers

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @State private var isImporting = false

    var body: some View {
        Group {
            Button("Add a GIF…") { isImporting = true }
                .keyboardShortcut("o", modifiers: .command)

            SettingsLink {
                Text("Settings…")
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.gif],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                appState.addGIF(at: url.path)
            }
        }
    }
}
