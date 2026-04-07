//
//  NoteGeneratorModule.swift
//  PerchNotes
//
//  Created by Codex on 4/7/26.
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

protocol NoteImageAnalyzing {
    func analyze(source_image: SourceImage) -> NoteImageAnalysisResult
}

enum NoteImageAnalysisResult {
    case success([DetectedPowerline])
    case failure(NoteGenerationFailureReason)
}

struct DetectedPowerline {
    let centerY: Double
    let prominenceScore: Double
    let birds: [DetectedBird]
}

struct DetectedBird {
    let centerX: Double
    let centerY: Double
    let darknessScore: Double
}

struct NoteGeneratorModule: NoteGenerator {
    enum Mode {
        case demoCompatible
        case analysisDriven(any NoteImageAnalyzing)
    }

    private let mode: Mode
    private let logHandler: (String) -> Void

    init(
        mode: Mode = .demoCompatible,
        logHandler: @escaping (String) -> Void = { print($0) }
    ) {
        self.mode = mode
        self.logHandler = logHandler
    }

    func generateNotes(
        source_image: SourceImage,
        note_generation_request: NoteGenerationRequest
    ) -> (note_sequence: NoteSequence?, note_generation_result: NoteGenerationResult) {
        log("input received: source_image=\(describe(source_image)), note_generation_request=\(describe(note_generation_request)), mode=\(describeMode())")

        switch mode {
        case .demoCompatible:
            return generateDemoCompatibleNotes(source_image: source_image)

        case .analysisDriven(let analyzer):
            log("intended behavior: analyze one source image, select one single most prominent valid powerline, order birds left-to-right, and map them into deterministic note events")
            let analysisResult = analyzer.analyze(source_image: source_image)
            log("analysis result: \(describe(analysisResult))")

            switch analysisResult {
            case .failure(let reason):
                let failure = NoteGenerationResult(status: .FAILED, reason: reason)
                log("output produced: note_sequence=nil, note_generation_result=\(describe(failure))")
                return (nil, failure)

            case .success(let detectedPowerlines):
                guard let selectedPowerline = selectSingleMostProminentPowerline(from: detectedPowerlines) else {
                    let failure = NoteGenerationResult(status: .FAILED, reason: .AMBIGUOUS_POWERLINE_SELECTION)
                    log("decision path: multiple valid powerlines could not be resolved to one unambiguous selection")
                    log("output produced: note_sequence=nil, note_generation_result=\(describe(failure))")
                    return (nil, failure)
                }

                log(
                    "selected powerline: center_y=\(format(selectedPowerline.centerY)), prominence_score=\(format(selectedPowerline.prominenceScore)), bird_count=\(selectedPowerline.birds.count)"
                )

                guard selectedPowerline.birds.isEmpty == false else {
                    let failure = NoteGenerationResult(status: .FAILED, reason: .NO_BIRDS_DETECTED)
                    log("decision path: selected powerline contained no usable birds")
                    log("output produced: note_sequence=nil, note_generation_result=\(describe(failure))")
                    return (nil, failure)
                }

                guard let orderedBirds = orderedBirds(from: selectedPowerline.birds) else {
                    let failure = NoteGenerationResult(status: .FAILED, reason: .AMBIGUOUS_NOTE_ORDER)
                    log("decision path: bird ordering was ambiguous for the selected powerline")
                    log("output produced: note_sequence=nil, note_generation_result=\(describe(failure))")
                    return (nil, failure)
                }

                log(
                    "note ordering behavior: ordered_centers_x=[\(orderedBirds.map { format($0.centerX) }.joined(separator: ", "))], ordered_centers_y=[\(orderedBirds.map { format($0.centerY) }.joined(separator: ", "))]"
                )

                let events = makeNoteEvents(from: orderedBirds)
                let noteSequence = NoteSequence(
                    source_image_id: source_image.image_id,
                    note_count: events.count,
                    events: events
                )
                let success = NoteGenerationResult(status: .SUCCESS, reason: nil)

                log("output produced: note_sequence=\(describe(noteSequence)), note_generation_result=\(describe(success))")
                return (noteSequence, success)
            }
        }
    }

    private func generateDemoCompatibleNotes(
        source_image: SourceImage
    ) -> (note_sequence: NoteSequence?, note_generation_result: NoteGenerationResult) {
        let trimmedImageReference = source_image.image_reference.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedImageReference.isEmpty {
            log("decision path: source image reference is empty in demo-compatible mode, returning IMAGE_ANALYSIS_FAILED")
            let failure = NoteGenerationResult(status: .FAILED, reason: .IMAGE_ANALYSIS_FAILED)
            log("output produced: note_sequence=nil, note_generation_result=\(describe(failure))")
            return (nil, failure)
        }

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

        log("decision path: demo-compatible mode produced deterministic stub-style note events")
        log("selected powerline: demo-compatible mode")
        log("note ordering behavior: demo-compatible left-to-right ordering by generated index")
        log("output produced: note_sequence=\(describe(noteSequence)), note_generation_result=\(describe(success))")
        return (noteSequence, success)
    }

    private func selectSingleMostProminentPowerline(
        from detectedPowerlines: [DetectedPowerline]
    ) -> DetectedPowerline? {
        let sortedPowerlines = detectedPowerlines.sorted { lhs, rhs in
            if lhs.prominenceScore == rhs.prominenceScore {
                return lhs.centerY < rhs.centerY
            }
            return lhs.prominenceScore > rhs.prominenceScore
        }

        guard let top = sortedPowerlines.first else {
            return nil
        }

        if sortedPowerlines.count > 1 {
            let second = sortedPowerlines[1]
            if abs(top.prominenceScore - second.prominenceScore) < 0.0001 {
                return nil
            }
        }

        return top
    }

    private func orderedBirds(from birds: [DetectedBird]) -> [DetectedBird]? {
        let sortedBirds = birds.sorted { lhs, rhs in
            if lhs.centerX == rhs.centerX {
                return lhs.centerY < rhs.centerY
            }
            return lhs.centerX < rhs.centerX
        }

        for pair in zip(sortedBirds, sortedBirds.dropFirst()) {
            let left = pair.0
            let right = pair.1
            if abs(left.centerX - right.centerX) < 1.0 {
                return nil
            }
        }

        return sortedBirds
    }

    private func makeNoteEvents(from birds: [DetectedBird]) -> [NoteEvent] {
        let quantizedHeights = birds.map { Int($0.centerY.rounded()) }
        let uniqueHeights = Array(Set(quantizedHeights)).sorted()
        let rankByHeight = Dictionary(
            uniqueKeysWithValues: uniqueHeights.enumerated().map { index, height in
                (height, uniqueHeights.count - index)
            }
        )

        return birds.enumerated().map { index, bird in
            let pitchRank = rankByHeight[Int(bird.centerY.rounded())] ?? 1
            return NoteEvent(
                order_index: index,
                pitch_rank: pitchRank,
                start_offset_units: index,
                duration_units: 1
            )
        }
    }

    private func deterministicEventCount(for imageID: String) -> Int {
        (imageID.count % 3) + 3
    }

    private func describeMode() -> String {
        switch mode {
        case .demoCompatible:
            return "demoCompatible"
        case .analysisDriven:
            return "analysisDriven"
        }
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

    private func describe(_ analysisResult: NoteImageAnalysisResult) -> String {
        switch analysisResult {
        case .failure(let reason):
            return "failure(reason: \(reason.rawValue))"
        case .success(let powerlines):
            let summary = powerlines
                .map { "center_y=\(format($0.centerY)), prominence=\(format($0.prominenceScore)), birds=\($0.birds.count)" }
                .joined(separator: "; ")
            return "success(powerlines: [\(summary)])"
        }
    }

    private func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func log(_ message: String) {
        logHandler("[NoteGeneratorModule] \(message)")
    }
}
