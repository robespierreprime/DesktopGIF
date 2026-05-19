// Persistence/PersistenceManager.swift

import Foundation

// MARK: – Codable snapshot bundling both arrays

struct AppPersistedState: Codable {
    var gifs:   [GIFItem]
    var groups: [GIFGroup]
}

// MARK: – Persistence manager

struct PersistenceManager {

    // ~/Library/Application Support/DesktopGIF/state.json
    static let stateURL: URL = {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("DesktopGIF", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir,
                                                  withIntermediateDirectories: true)
        return dir.appendingPathComponent("state.json")
    }()

    static func save(_ state: AppPersistedState) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(state)
        try data.write(to: stateURL, options: .atomic)
    }

    static func load() throws -> AppPersistedState {
        let data = try Data(contentsOf: stateURL)
        return try JSONDecoder().decode(AppPersistedState.self, from: data)
    }
}
