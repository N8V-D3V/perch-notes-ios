//
//  AudioGeneratorModule.swift
//  PerchNotes
//
//  Created by Codex on 4/7/26.
//

import Foundation

enum AudioGenerationStatus: String, Sendable {
    case SUCCESS
    case FAILED
}

enum AudioGenerationFailureReason: String, Sendable {
    case MISSING_NOTE_SEQUENCE
    case EMPTY_NOTE_SEQUENCE
    case INVALID_NOTE_TIMING
    case INVALID_NOTE_SEQUENCE
    case AUDIO_GENERATION_FAILED
}

struct AudioGenerationRequest: Sendable, Equatable {
    let request_id: String
}

struct GeneratedAudio: Sendable, Equatable {
    let audio_id: String
    let source_image_id: String
    let note_count: Int
    let loopable: Bool
    let audio_reference: String
}

struct AudioGenerationResult: Sendable, Equatable {
    let status: AudioGenerationStatus
    let reason: AudioGenerationFailureReason?
}

protocol AudioGenerator {
    func generateAudio(
        note_sequence: NoteSequence,
        audio_generation_request: AudioGenerationRequest
    ) -> (generated_audio: GeneratedAudio?, audio_generation_result: AudioGenerationResult)
}

struct AudioGeneratorModule: AudioGenerator {
    private let renderer: DeterministicWaveAudioRenderer
    private let logHandler: (String) -> Void

    init(
        renderer: DeterministicWaveAudioRenderer = DeterministicWaveAudioRenderer(),
        logHandler: @escaping (String) -> Void = { print($0) }
    ) {
        self.renderer = renderer
        self.logHandler = logHandler
    }

    func generateAudio(
        note_sequence: NoteSequence,
        audio_generation_request: AudioGenerationRequest
    ) -> (generated_audio: GeneratedAudio?, audio_generation_result: AudioGenerationResult) {
        log("input received: note_sequence=\(describe(note_sequence)), audio_generation_request=\(describe(audio_generation_request))")
        log("validation path: checking note sequence presence, count, order, timing, and pitch values before rendering")

        guard note_sequence.events.isEmpty == false, note_sequence.note_count > 0 else {
            log("decision path: note sequence is empty, returning EMPTY_NOTE_SEQUENCE")
            return failure(.EMPTY_NOTE_SEQUENCE)
        }

        guard note_sequence.note_count == note_sequence.events.count else {
            log("decision path: note_count does not match events.count, returning INVALID_NOTE_SEQUENCE")
            return failure(.INVALID_NOTE_SEQUENCE)
        }

        let hasInvalidOrder = note_sequence.events.enumerated().contains { index, event in
            event.order_index != index
        }
        guard hasInvalidOrder == false else {
            log("decision path: order_index values are not sequential within the returned event order, returning INVALID_NOTE_SEQUENCE")
            return failure(.INVALID_NOTE_SEQUENCE)
        }

        let hasInvalidTiming = note_sequence.events.contains { event in
            event.start_offset_units != event.order_index || event.duration_units != 1
        }
        guard hasInvalidTiming == false else {
            log("decision path: timing validation failed because start_offset_units or duration_units violated the v0.1 timing contract, returning INVALID_NOTE_TIMING")
            return failure(.INVALID_NOTE_TIMING)
        }

        let hasInvalidPitch = note_sequence.events.contains { event in
            event.pitch_rank <= 0
        }
        guard hasInvalidPitch == false else {
            log("decision path: at least one note event has a non-positive pitch_rank, returning INVALID_NOTE_SEQUENCE")
            return failure(.INVALID_NOTE_SEQUENCE)
        }

        log("intended behavior: map each pitch_rank into a deterministic tone, render one PCM wave file, and return one playable loopable audio artifact")

        do {
            let renderedArtifact = try renderer.render(noteSequence: note_sequence)
            log("note-to-audio mapping behavior: \(renderedArtifact.mappingDescription)")

            let generatedAudio = GeneratedAudio(
                audio_id: renderedArtifact.audioID,
                source_image_id: note_sequence.source_image_id,
                note_count: note_sequence.note_count,
                loopable: true,
                audio_reference: renderedArtifact.audioReference
            )
            let success = AudioGenerationResult(status: .SUCCESS, reason: nil)

            log("decision path: real audio generation succeeded after validation and deterministic rendering")
            log("output produced: generated_audio=\(describe(generatedAudio)), audio_generation_result=\(describe(success))")
            return (generatedAudio, success)
        } catch {
            log("decision path: renderer failed to produce a playable artifact, returning AUDIO_GENERATION_FAILED, error=\(error)")
            return failure(.AUDIO_GENERATION_FAILED)
        }
    }

    private func describe(_ request: AudioGenerationRequest) -> String {
        "AudioGenerationRequest(request_id: \(request.request_id))"
    }

    private func describe(_ noteSequence: NoteSequence) -> String {
        let eventsDescription = noteSequence.events
            .map { event in
                "(order_index: \(event.order_index), pitch_rank: \(event.pitch_rank), start_offset_units: \(event.start_offset_units), duration_units: \(event.duration_units))"
            }
            .joined(separator: ", ")
        return "NoteSequence(source_image_id: \(noteSequence.source_image_id), note_count: \(noteSequence.note_count), events: [\(eventsDescription)])"
    }

    private func describe(_ generatedAudio: GeneratedAudio) -> String {
        "GeneratedAudio(audio_id: \(generatedAudio.audio_id), source_image_id: \(generatedAudio.source_image_id), note_count: \(generatedAudio.note_count), loopable: \(generatedAudio.loopable), audio_reference: \(generatedAudio.audio_reference))"
    }

    private func describe(_ result: AudioGenerationResult) -> String {
        "AudioGenerationResult(status: \(result.status.rawValue), reason: \(result.reason?.rawValue ?? "nil"))"
    }

    private func failure(
        _ reason: AudioGenerationFailureReason
    ) -> (generated_audio: GeneratedAudio?, audio_generation_result: AudioGenerationResult) {
        let result = AudioGenerationResult(status: .FAILED, reason: reason)
        log("output produced: generated_audio=nil, audio_generation_result=\(describe(result))")
        return (nil, result)
    }

    private func log(_ message: String) {
        logHandler("[AudioGeneratorModule] \(message)")
    }
}
