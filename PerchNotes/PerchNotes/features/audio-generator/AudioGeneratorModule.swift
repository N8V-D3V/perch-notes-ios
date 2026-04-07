//
//  AudioGeneratorModule.swift
//  PerchNotes
//
//  Created by Codex on 4/6/26.
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
    private let logHandler: (String) -> Void

    init(logHandler: @escaping (String) -> Void = { print($0) }) {
        self.logHandler = logHandler
    }

    func generateAudio(
        note_sequence: NoteSequence,
        audio_generation_request: AudioGenerationRequest
    ) -> (generated_audio: GeneratedAudio?, audio_generation_result: AudioGenerationResult) {
        log("input received: note_sequence=\(describe(note_sequence)), audio_generation_request=\(describe(audio_generation_request))")

        if note_sequence.events.isEmpty || note_sequence.note_count == 0 {
            log("decision path: note sequence is empty, returning EMPTY_NOTE_SEQUENCE")
            let failure = AudioGenerationResult(status: .FAILED, reason: .EMPTY_NOTE_SEQUENCE)
            log("output produced: generated_audio=nil, audio_generation_result=\(describe(failure))")
            return (nil, failure)
        }

        if note_sequence.note_count != note_sequence.events.count {
            log("decision path: note_count does not match events.count, returning INVALID_NOTE_SEQUENCE")
            let failure = AudioGenerationResult(status: .FAILED, reason: .INVALID_NOTE_SEQUENCE)
            log("output produced: generated_audio=nil, audio_generation_result=\(describe(failure))")
            return (nil, failure)
        }

        let hasInvalidTiming = note_sequence.events.enumerated().contains { index, event in
            event.start_offset_units != event.order_index || event.duration_units != 1 || event.order_index != index
        }
        if hasInvalidTiming {
            log("decision path: sequential timing validation failed, returning INVALID_NOTE_TIMING")
            let failure = AudioGenerationResult(status: .FAILED, reason: .INVALID_NOTE_TIMING)
            log("output produced: generated_audio=nil, audio_generation_result=\(describe(failure))")
            return (nil, failure)
        }

        log("intended behavior: validate one deterministic note sequence and render one playable loopable audio artifact without real synthesis")

        let generatedAudio = GeneratedAudio(
            audio_id: deterministicAudioID(for: note_sequence),
            source_image_id: note_sequence.source_image_id,
            note_count: note_sequence.note_count,
            loopable: true,
            audio_reference: deterministicAudioReference(for: note_sequence)
        )
        let success = AudioGenerationResult(status: .SUCCESS, reason: nil)

        log("decision path: stub audio generation succeeded after sequence validation")
        log("output produced: generated_audio=\(describe(generatedAudio)), audio_generation_result=\(describe(success))")
        return (generatedAudio, success)
    }

    private func deterministicAudioID(for noteSequence: NoteSequence) -> String {
        "stub-audio-\(noteSequence.source_image_id)-\(noteSequence.note_count)"
    }

    private func deterministicAudioReference(for noteSequence: NoteSequence) -> String {
        "stub://audio/\(noteSequence.source_image_id)/\(noteSequence.note_count)"
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

    private func log(_ message: String) {
        logHandler("[AudioGeneratorModule] \(message)")
    }
}
