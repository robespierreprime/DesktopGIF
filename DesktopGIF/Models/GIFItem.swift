// Models/GIFItem.swift — Étape E

import Foundation
import CoreGraphics

struct GIFItem: Identifiable, Codable {
    let id: UUID
    var filePath: String        // chemin absolu local
    var positionX: Double
    var positionY: Double
    var width: Double
    var height: Double
    var isLocked: Bool
    var isVisible: Bool

    // MARK: – Étape A : ancrage écran
    var screenID: UInt32
    var screenRelativeX: Double
    var screenRelativeY: Double

    // MARK: – Étape E2 : vitesse de lecture
    // Multiplicateur de vitesse. 1.0 = vitesse normale.
    // Plage recommandée [0.25, 4.0].
    var playbackSpeed: Double

    // MARK: – Étape E4 : nom d'affichage
    // nil = utiliser lastPathComponent du filePath.
    // Suffixé automatiquement si doublon à l'import.
    var displayName: String?

    // MARK: – Init

    init(filePath: String,
         position: CGPoint = .init(x: 100, y: 100),
         size: CGSize = .init(width: 200, height: 200)) {
        self.id              = UUID()
        self.filePath        = filePath
        self.positionX       = position.x
        self.positionY       = position.y
        self.width           = size.width
        self.height          = size.height
        self.isLocked        = false
        self.isVisible       = true
        self.screenID        = 0
        self.screenRelativeX = 0
        self.screenRelativeY = 0
        self.playbackSpeed   = 1.0
        self.displayName     = nil
    }

    // MARK: – Computed helpers

    var frame: CGRect {
        CGRect(x: positionX, y: positionY, width: width, height: height)
    }

    var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }

    /// Nom affiché dans l'UI. Utilise displayName si défini, sinon le lastPathComponent.
    var label: String {
        displayName ?? fileURL.lastPathComponent
    }

    // MARK: – Codable

    enum CodingKeys: String, CodingKey {
        case id, filePath, positionX, positionY
        case width, height, isLocked, isVisible
        case screenID, screenRelativeX, screenRelativeY
        case playbackSpeed, displayName
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(UUID.self,   forKey: .id)
        filePath  = try c.decode(String.self, forKey: .filePath)
        positionX = try c.decode(Double.self, forKey: .positionX)
        positionY = try c.decode(Double.self, forKey: .positionY)
        width     = try c.decode(Double.self, forKey: .width)
        height    = try c.decode(Double.self, forKey: .height)
        isLocked  = try c.decode(Bool.self,   forKey: .isLocked)
        isVisible = try c.decode(Bool.self,   forKey: .isVisible)
        screenID        = try c.decodeIfPresent(UInt32.self,  forKey: .screenID)        ?? 0
        screenRelativeX = try c.decodeIfPresent(Double.self,  forKey: .screenRelativeX) ?? 0
        screenRelativeY = try c.decodeIfPresent(Double.self,  forKey: .screenRelativeY) ?? 0
        playbackSpeed   = try c.decodeIfPresent(Double.self,  forKey: .playbackSpeed)   ?? 1.0
        displayName     = try c.decodeIfPresent(String.self,  forKey: .displayName)
    }
}
