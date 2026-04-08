//
//  CorePipelineLoopPlaybackController.swift
//  PerchNotes
//
//  Created by Codex on 4/7/26.
//

import AVFoundation
import Foundation

@MainActor
final class CorePipelineLoopPlaybackController: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var activeAudioReference: String?
    @Published private(set) var playbackErrorMessage: String?

    private var player: AVAudioPlayer?
    private let logHandler: (String) -> Void

    init(logHandler: @escaping (String) -> Void = { print($0) }) {
        self.logHandler = logHandler
    }

    func togglePlayback(audioReference: String) {
        if isPlaying, activeAudioReference == audioReference {
            stopPlayback()
            return
        }

        do {
            let audioURL = try resolveAudioURL(from: audioReference)
            let player = try AVAudioPlayer(contentsOf: audioURL)
            player.numberOfLoops = -1
            player.delegate = self
            player.prepareToPlay()

            #if os(iOS)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            #endif

            stopPlayback(clearError: false)

            self.player = player
            self.activeAudioReference = audioReference
            self.playbackErrorMessage = nil

            guard player.play() else {
                throw PlaybackError.playbackStartFailed
            }

            isPlaying = true
            log("playback started: audio_reference=\(audioReference)")
        } catch {
            stopPlayback(clearError: false)
            playbackErrorMessage = "Playback isn’t available for this loop right now."
            log("playback failed: audio_reference=\(audioReference), error=\(error)")
        }
    }

    func stopPlayback(clearError: Bool = true) {
        player?.stop()
        player = nil
        isPlaying = false
        activeAudioReference = nil

        if clearError {
            playbackErrorMessage = nil
        }

        log("playback stopped")
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        self.player = nil
        activeAudioReference = nil
        log("playback finished: successfully=\(flag)")
    }

    private func resolveAudioURL(from audioReference: String) throws -> URL {
        let trimmedReference = audioReference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedReference.isEmpty == false else {
            throw PlaybackError.invalidAudioReference
        }

        if let url = URL(string: trimmedReference), url.isFileURL {
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw PlaybackError.audioFileMissing
            }
            return url
        }

        let fileURL = URL(fileURLWithPath: trimmedReference)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw PlaybackError.audioFileMissing
        }
        return fileURL
    }

    private func log(_ message: String) {
        logHandler("[CorePipelineLoopPlaybackController] \(message)")
    }
}

private enum PlaybackError: Error {
    case invalidAudioReference
    case audioFileMissing
    case playbackStartFailed
}
