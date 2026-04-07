//
//  NoteGeneratorModule.swift
//  PerchNotes
//
//  Created by Codex on 4/6/26.
//

import Foundation

enum NoteGenerationStatus: String, Sendable {
    case SUCCESS
    case FAILED
}

enum NoteGenerationFailureReason: String, Sendable {
    case NO_VALID_POWERLINE
    case NO_BIRDS_DETECTED
    case AMBIGUOUS_POWERLINE_SELECTION
    case IMAGE_ANALYSIS_FAILED
    case AMBIGUOUS_NOTE_ORDER
}

struct NoteGenerationRequest: Sendable, Equatable {
    let request_id: String
}

struct NoteEvent: Sendable, Equatable {
    let order_index: Int
    let pitch_rank: Int
    let start_offset_units: Int
    let duration_units: Int
}

struct NoteSequence: Sendable, Equatable {
    let source_image_id: String
    let note_count: Int
    let events: [NoteEvent]
}

struct NoteGenerationResult: Sendable, Equatable {
    let status: NoteGenerationStatus
    let reason: NoteGenerationFailureReason?
}

protocol NoteGenerator {
    func generateNotes(
        source_image: SourceImage,
        note_generation_request: NoteGenerationRequest
    ) -> (note_sequence: NoteSequence?, note_generation_result: NoteGenerationResult)
}

struct NoteGeneratorModule: NoteGenerator {
    private let logHandler: (String) -> Void

    init(logHandler: @escaping (String) -> Void = { print($0) }) {
        self.logHandler = logHandler
    }

    func generateNotes(
        source_image: SourceImage,
        note_generation_request: NoteGenerationRequest
    ) -> (note_sequence: NoteSequence?, note_generation_result: NoteGenerationResult) {
        log("input received: source_image=\(describe(source_image)), note_generation_request=\(describe(note_generation_request))")

        let trimmedImageReference = source_image.image_reference.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedImageReference.isEmpty {
            log("decision path: source image reference is empty, stub cannot simulate analysis, returning IMAGE_ANALYSIS_FAILED")
            let failure = NoteGenerationResult(status: .FAILED, reason: .IMAGE_ANALYSIS_FAILED)
            log("output produced: note_sequence=nil, note_generation_result=\(describe(failure))")
            return (nil, failure)
        }

        log("intended behavior: analyze one source image, choose a single prominent powerline, order birds left-to-right, and map their positions to note events without real image processing")

        let eventCount = deterministicEventCount(for: source_image.image_id)
        let events = (0..<eventCount).map { index in
            NoteEvent(
                order_index: index,
                pitch_rank: index + 1,
                start_offset_units: index,
                duration_units: 1
            )
        }
        let noteSequence = NoteSequence(
            source_image_id: source_image.image_id,
            note_count: events.count,
            events: events
        )
        let success = NoteGenerationResult(status: .SUCCESS, reason: nil)

        log("decision path: stub selected one simulated powerline with \(events.count) left-to-right birds")
        log("output produced: note_sequence=\(describe(noteSequence)), note_generation_result=\(describe(success))")
        return (noteSequence, success)
    }

    private func deterministicEventCount(for imageID: String) -> Int {
        (imageID.count % 3) + 3
    }

    private func describe(_ sourceImage: SourceImage) -> String {
        "SourceImage(image_id: \(sourceImage.image_id), origin_method: \(sourceImage.origin_method.rawValue), image_reference: \(sourceImage.image_reference))"
    }

    private func describe(_ request: NoteGenerationRequest) -> String {
        "NoteGenerationRequest(request_id: \(request.request_id))"
    }

    private func describe(_ noteSequence: NoteSequence) -> String {
        let eventsDescription = noteSequence.events
            .map { event in
                "(order_index: \(event.order_index), pitch_rank: \(event.pitch_rank), start_offset_units: \(event.start_offset_units), duration_units: \(event.duration_units))"
            }
            .joined(separator: ", ")
        return "NoteSequence(source_image_id: \(noteSequence.source_image_id), note_count: \(noteSequence.note_count), events: [\(eventsDescription)])"
    }

    private func describe(_ result: NoteGenerationResult) -> String {
        "NoteGenerationResult(status: \(result.status.rawValue), reason: \(result.reason?.rawValue ?? "nil"))"
    }

    private func log(_ message: String) {
        logHandler("[NoteGeneratorModule] \(message)")
    }
}
