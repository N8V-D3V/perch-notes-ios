//
//  AudioGeneratorRendering.swift
//  PerchNotes
//
//  Created by Codex on 4/7/26.
//

import CryptoKit
import Foundation

struct DeterministicWaveAudioRenderer {
    private let sampleRate = 24_000
    private let samplesPerUnit = 6_000
    private let fadeSampleCount = 96
    private let amplitudeScale = 0.35

    func render(noteSequence: NoteSequence) throws -> RenderedAudioArtifact {
        let audioID = stableAudioID(for: noteSequence)
        let fileURL = try outputFileURL(for: audioID)

        var samples: [Int16] = []
        samples.reserveCapacity(noteSequence.events.count * samplesPerUnit)
        var mappedFrequencies: [Double] = []
        mappedFrequencies.reserveCapacity(noteSequence.events.count)

        for event in noteSequence.events {
            let frequency = frequency(for: event.pitch_rank)
            mappedFrequencies.append(frequency)
            appendSamples(for: frequency, into: &samples)
        }

        let waveData = makeWaveData(from: samples)
        try waveData.write(to: fileURL, options: .atomic)

        return RenderedAudioArtifact(
            audioID: audioID,
            audioReference: fileURL.absoluteString,
            mappingDescription: mappingDescription(for: noteSequence.events, frequencies: mappedFrequencies),
            sampleCount: samples.count
        )
    }

    private func frequency(for pitchRank: Int) -> Double {
        let normalizedRank = max(1.0, Double(pitchRank))
        return 220.0 * pow(normalizedRank, 1.0 / 3.0)
    }

    private func appendSamples(for frequency: Double, into samples: inout [Int16]) {
        let maxAmplitude = Double(Int16.max) * amplitudeScale

        for sampleIndex in 0..<samplesPerUnit {
            let time = Double(sampleIndex) / Double(sampleRate)
            let phase = 2.0 * Double.pi * frequency * time
            let envelope = envelopeScale(for: sampleIndex)
            let amplitude = sin(phase) * maxAmplitude * envelope
            let clampedAmplitude = max(Double(Int16.min), min(Double(Int16.max), amplitude))
            samples.append(Int16(clampedAmplitude.rounded()))
        }
    }

    private func envelopeScale(for sampleIndex: Int) -> Double {
        let fadeLength = min(fadeSampleCount, samplesPerUnit / 2)
        guard fadeLength > 0 else {
            return 1.0
        }

        if sampleIndex < fadeLength {
            return Double(sampleIndex) / Double(fadeLength)
        }

        let trailingIndex = samplesPerUnit - sampleIndex - 1
        if trailingIndex < fadeLength {
            return Double(trailingIndex) / Double(fadeLength)
        }

        return 1.0
    }

    private func makeWaveData(from samples: [Int16]) -> Data {
        let channelCount = 1
        let bitsPerSample = 16
        let blockAlign = channelCount * (bitsPerSample / 8)
        let byteRate = sampleRate * blockAlign
        let dataChunkSize = samples.count * blockAlign

        var data = Data()
        data.appendASCII("RIFF")
        data.appendLittleEndian(UInt32(36 + dataChunkSize))
        data.appendASCII("WAVE")
        data.appendASCII("fmt ")
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt16(channelCount))
        data.appendLittleEndian(UInt32(sampleRate))
        data.appendLittleEndian(UInt32(byteRate))
        data.appendLittleEndian(UInt16(blockAlign))
        data.appendLittleEndian(UInt16(bitsPerSample))
        data.appendASCII("data")
        data.appendLittleEndian(UInt32(dataChunkSize))

        for sample in samples {
            data.appendLittleEndian(UInt16(bitPattern: sample))
        }

        return data
    }

    private func outputFileURL(for audioID: String) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("perch-notes-generated-audio", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL.appendingPathComponent("\(audioID).wav")
    }

    private func stableAudioID(for noteSequence: NoteSequence) -> String {
        let serializedEvents = noteSequence.events
            .map { event in
                "\(event.order_index),\(event.pitch_rank),\(event.start_offset_units),\(event.duration_units)"
            }
            .joined(separator: ";")
        let signature = "audio-v1|\(noteSequence.source_image_id)|\(noteSequence.note_count)|\(serializedEvents)"
        let digest = SHA256.hash(data: Data(signature.utf8))
        return "audio-\(digest.map { String(format: "%02x", $0) }.joined())"
    }

    private func mappingDescription(for events: [NoteEvent], frequencies: [Double]) -> String {
        let pairs = zip(events, frequencies).map { event, frequency in
            "(order_index: \(event.order_index), pitch_rank: \(event.pitch_rank), frequency_hz: \(String(format: "%.2f", frequency)))"
        }
        return pairs.joined(separator: ", ")
    }
}

struct RenderedAudioArtifact {
    let audioID: String
    let audioReference: String
    let mappingDescription: String
    let sampleCount: Int
}

private extension Data {
    mutating func appendASCII(_ string: String) {
        append(Data(string.utf8))
    }

    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { buffer in
            append(buffer.bindMemory(to: UInt8.self))
        }
    }
}
