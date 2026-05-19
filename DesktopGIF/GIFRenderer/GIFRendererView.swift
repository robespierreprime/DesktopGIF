// GIFRenderer/GIFRendererView.swift — Étape E2 : contrôle vitesse de lecture

import SwiftUI
import AppKit
import ImageIO
import CoreGraphics

// MARK: – NSViewRepresentable wrapper

struct GIFRendererView: NSViewRepresentable {
    let fileURL: URL

    func makeNSView(context: Context) -> GIFImageView {
        // Ne charge PAS ici — le contrôleur appelle resume() au bon moment.
        GIFImageView(fileURL: fileURL)
    }

    func updateNSView(_ view: GIFImageView, context: Context) {}
}

// MARK: – Vue AppKit gérant l'animation GIF frame par frame

final class GIFImageView: NSView {

    // MARK: Propriétés privées

    private let fileURL: URL

    private var frames:       [CGImage]      = []
    private var delays:       [TimeInterval] = []
    private var currentIndex: Int            = 0
    private var timer:        Timer?

    private var imageLayer = CALayer()

    // Jeton de génération : incrémenté à chaque pause() ou load lancé.
    private var loadGeneration: Int = 0

    // État observable pour éviter des resume() redondants
    private var isLoaded = false

    // MARK: – Étape E2 : vitesse de lecture
    // Multiplicateur appliqué sur chaque délai inter-frames.
    // Modifiable à chaud via setPlaybackSpeed(_:) sans rechargement des frames.
    var playbackSpeed: Double = 1.0

    // MARK: Init

    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = .clear

        imageLayer.contentsGravity = .resizeAspect
        imageLayer.backgroundColor = .clear
        layer?.addSublayer(imageLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        imageLayer.frame = bounds
    }

    // MARK: – API publique

    /// Charge les frames depuis le disque et démarre l'animation.
    /// Idempotent : sans effet si déjà chargé et en cours d'animation.
    func resume() {
        guard !isLoaded else { return }
        isLoaded = true

        loadGeneration &+= 1
        let generation = loadGeneration

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            guard let source = CGImageSourceCreateWithURL(self.fileURL as CFURL, nil) else {
                print("GIFImageView: impossible de lire \(self.fileURL)")
                return
            }

            let count = CGImageSourceGetCount(source)
            var loadedFrames: [CGImage]      = []
            var loadedDelays: [TimeInterval] = []
            loadedFrames.reserveCapacity(count)
            loadedDelays.reserveCapacity(count)

            for i in 0..<count {
                guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil)
                else { continue }
                loadedFrames.append(cgImage)
                loadedDelays.append(Self.frameDelay(at: i, source: source))
            }

            DispatchQueue.main.async { [weak self] in
                guard let self, self.loadGeneration == generation else { return }
                self.frames       = loadedFrames
                self.delays       = loadedDelays
                self.currentIndex = 0
                self.startAnimation()
            }
        }
    }

    /// Stoppe l'animation, vide les frames de la mémoire et efface le layer.
    /// Idempotent : sans effet si déjà en pause.
    func pause() {
        guard isLoaded else { return }
        isLoaded = false

        loadGeneration &+= 1

        timer?.invalidate()
        timer = nil

        frames = []
        delays = []
        currentIndex = 0

        imageLayer.contents = nil
    }

    /// Met à jour le multiplicateur de vitesse et relance immédiatement le timer
    /// avec le nouveau délai — sans recharger les frames.
    func setPlaybackSpeed(_ speed: Double) {
        playbackSpeed = speed
        guard isLoaded, !delays.isEmpty else { return }
        timer?.invalidate()
        timer = nil
        scheduleNext()
    }

    // MARK: – Animation (privé)

    private func startAnimation() {
        guard !frames.isEmpty else { return }
        showFrame(at: 0)
        scheduleNext()
    }

    private func scheduleNext() {
        guard !delays.isEmpty else { return }
        // Étape E2 : diviser le délai brut par playbackSpeed, plancher à 16 ms (~60 fps).
        let rawDelay      = delays[currentIndex]
        let adjustedDelay = max(0.016, rawDelay / playbackSpeed)

        let t = Timer(timeInterval: adjustedDelay, repeats: false) { [weak self] _ in
            guard let self, self.isLoaded else { return }
            self.currentIndex = (self.currentIndex + 1) % self.frames.count
            self.showFrame(at: self.currentIndex)
            self.scheduleNext()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func showFrame(at index: Int) {
        imageLayer.contents = frames[index]
    }

    // MARK: – Délai inter-frames (métadonnées ImageIO)

    private static func frameDelay(at index: Int, source: CGImageSource) -> TimeInterval {
        let fallback: TimeInterval = 0.1
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil)
                as? [String: Any],
              let gifProps = props[kCGImagePropertyGIFDictionary as String]
                as? [String: Any]
        else { return fallback }

        if let d = gifProps[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double,
           d > 0 { return d }
        if let d = gifProps[kCGImagePropertyGIFDelayTime as String] as? Double,
           d > 0 { return d }
        return fallback
    }

    deinit {
        timer?.invalidate()
    }
}
