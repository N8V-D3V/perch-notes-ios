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
    let pitch_ranks: [Int]
    let start_offset_units: Int
    let duration_units: Int
}

struct NoteSequence: Sendable, Equatable {
    let source_image_id: String
    let line_count: Int
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
    let slope: Double
    let spanWidth: Double
    let supportCount: Int
    let averageBirdDistance: Double
    let centralityScore: Double
    let residualLineThickness: Double
    let averageSupportThickness: Double
    let continuityRatio: Double
    let maximumGapRatio: Double
    let averageAlignmentError: Double

    init(
        centerY: Double,
        prominenceScore: Double,
        birds: [DetectedBird],
        slope: Double = 0,
        spanWidth: Double = 0,
        supportCount: Int = 0,
        averageBirdDistance: Double = 0,
        centralityScore: Double = 0,
        residualLineThickness: Double = 0,
        averageSupportThickness: Double = 0,
        continuityRatio: Double = 0,
        maximumGapRatio: Double = 0,
        averageAlignmentError: Double = 0
    ) {
        self.centerY = centerY
        self.prominenceScore = prominenceScore
        self.birds = birds
        self.slope = slope
        self.spanWidth = spanWidth
        self.supportCount = supportCount
        self.averageBirdDistance = averageBirdDistance
        self.centralityScore = centralityScore
        self.residualLineThickness = residualLineThickness
        self.averageSupportThickness = averageSupportThickness
        self.continuityRatio = continuityRatio
        self.maximumGapRatio = maximumGapRatio
        self.averageAlignmentError = averageAlignmentError
    }
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
                log("line selection behavior: candidate_count=\(detectedPowerlines.count)")
                logCandidateRankings(detectedPowerlines)

                guard let selectedPowerline = selectSingleMostProminentPowerline(from: detectedPowerlines) else {
                    let failure = NoteGenerationResult(status: .FAILED, reason: .AMBIGUOUS_POWERLINE_SELECTION)
                    log("decision path: multiple valid powerlines remained indistinguishable after deterministic ranking, returning AMBIGUOUS_POWERLINE_SELECTION")
                    log("output produced: note_sequence=nil, note_generation_result=\(describe(failure))")
                    return (nil, failure)
                }

                log(
                    "selected powerline: center_y=\(format(selectedPowerline.centerY)), slope=\(format(selectedPowerline.slope)), prominence_score=\(format(selectedPowerline.prominenceScore)), bird_count=\(selectedPowerline.birds.count), span_width=\(format(selectedPowerline.spanWidth)), support_count=\(selectedPowerline.supportCount), average_bird_distance=\(format(selectedPowerline.averageBirdDistance)), centrality_score=\(format(selectedPowerline.centralityScore)), residual_line_thickness=\(format(selectedPowerline.residualLineThickness)), average_support_thickness=\(format(selectedPowerline.averageSupportThickness)), continuity_ratio=\(format(selectedPowerline.continuityRatio)), maximum_gap_ratio=\(format(selectedPowerline.maximumGapRatio)), average_alignment_error=\(format(selectedPowerline.averageAlignmentError))"
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
                    line_count: 1,
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
                pitch_ranks: [index + 1],
                start_offset_units: index,
                duration_units: 1
            )
        }
        let noteSequence = NoteSequence(
            source_image_id: source_image.image_id,
            line_count: 1,
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
        let rankedPowerlines = detectedPowerlines.sorted { lhs, rhs in
            compareSelectionPriority(lhs, rhs)
        }

        guard let top = rankedPowerlines.first else {
            return nil
        }

        if rankedPowerlines.count > 1 {
            let second = rankedPowerlines[1]
            if hasEquivalentSelectionPriority(top, second) {
                log(
                    "selection ambiguity: top candidates remained tied after ranking. top=\(describeSelection(top)); second=\(describeSelection(second))"
                )
                return nil
            }
        }

        return top
    }

    private func compareSelectionPriority(_ lhs: DetectedPowerline, _ rhs: DetectedPowerline) -> Bool {
        if abs(lhs.prominenceScore - rhs.prominenceScore) >= 0.0001 {
            return lhs.prominenceScore > rhs.prominenceScore
        }

        if lhs.birds.count != rhs.birds.count {
            return lhs.birds.count > rhs.birds.count
        }

        if abs(lhs.spanWidth - rhs.spanWidth) >= 0.0001 {
            return lhs.spanWidth > rhs.spanWidth
        }

        if lhs.supportCount != rhs.supportCount {
            return lhs.supportCount > rhs.supportCount
        }

        if abs(lhs.continuityRatio - rhs.continuityRatio) >= 0.0001 {
            return lhs.continuityRatio > rhs.continuityRatio
        }

        if abs(lhs.averageBirdDistance - rhs.averageBirdDistance) >= 0.0001 {
            return lhs.averageBirdDistance < rhs.averageBirdDistance
        }

        if abs(lhs.maximumGapRatio - rhs.maximumGapRatio) >= 0.0001 {
            return lhs.maximumGapRatio < rhs.maximumGapRatio
        }

        if abs(lhs.averageAlignmentError - rhs.averageAlignmentError) >= 0.0001 {
            return lhs.averageAlignmentError < rhs.averageAlignmentError
        }

        if abs(lhs.residualLineThickness - rhs.residualLineThickness) >= 0.0001 {
            return lhs.residualLineThickness < rhs.residualLineThickness
        }

        if abs(lhs.averageSupportThickness - rhs.averageSupportThickness) >= 0.0001 {
            return lhs.averageSupportThickness < rhs.averageSupportThickness
        }

        if abs(lhs.centralityScore - rhs.centralityScore) >= 0.0001 {
            return lhs.centralityScore > rhs.centralityScore
        }

        if abs(abs(lhs.slope) - abs(rhs.slope)) >= 0.0001 {
            return abs(lhs.slope) < abs(rhs.slope)
        }

        return lhs.centerY < rhs.centerY
    }

    private func hasEquivalentSelectionPriority(_ lhs: DetectedPowerline, _ rhs: DetectedPowerline) -> Bool {
        abs(lhs.prominenceScore - rhs.prominenceScore) < 0.0001
            && lhs.birds.count == rhs.birds.count
            && abs(lhs.spanWidth - rhs.spanWidth) < 0.0001
            && lhs.supportCount == rhs.supportCount
            && abs(lhs.averageBirdDistance - rhs.averageBirdDistance) < 0.0001
            && abs(lhs.continuityRatio - rhs.continuityRatio) < 0.0001
            && abs(lhs.maximumGapRatio - rhs.maximumGapRatio) < 0.0001
            && abs(lhs.averageAlignmentError - rhs.averageAlignmentError) < 0.0001
            && abs(lhs.residualLineThickness - rhs.residualLineThickness) < 0.0001
            && abs(lhs.averageSupportThickness - rhs.averageSupportThickness) < 0.0001
            && abs(lhs.centralityScore - rhs.centralityScore) < 0.0001
            && abs(lhs.slope - rhs.slope) < 0.0001
            && abs(lhs.centerY - rhs.centerY) < 0.0001
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
                pitch_ranks: [pitchRank],
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
                "(order_index: \(event.order_index), pitch_ranks: \(event.pitch_ranks), start_offset_units: \(event.start_offset_units), duration_units: \(event.duration_units))"
            }
            .joined(separator: ", ")
        return "NoteSequence(source_image_id: \(noteSequence.source_image_id), line_count: \(noteSequence.line_count), note_count: \(noteSequence.note_count), events: [\(eventsDescription)])"
    }

    private func describe(_ result: NoteGenerationResult) -> String {
        "NoteGenerationResult(status: \(result.status.rawValue), reason: \(result.reason?.rawValue ?? "nil"))"
    }

    private func describe(_ analysisResult: NoteImageAnalysisResult) -> String {
        switch analysisResult {
        case .failure(let reason):
            return "failure(reason: \(reason.rawValue))"
        case .success(let powerlines):
            let summary = powerlines.map(describeSelection).joined(separator: "; ")
            return "success(powerlines: [\(summary)])"
        }
    }

    private func logCandidateRankings(_ powerlines: [DetectedPowerline]) {
        let rankedSummaries = powerlines
            .sorted(by: compareSelectionPriority)
            .enumerated()
            .map { index, powerline in
                "#\(index + 1) \(describeSelection(powerline))"
            }
            .joined(separator: " | ")

        log("line candidate rankings: \(rankedSummaries)")
    }

    private func describeSelection(_ powerline: DetectedPowerline) -> String {
        "center_y=\(format(powerline.centerY)), slope=\(format(powerline.slope)), prominence=\(format(powerline.prominenceScore)), birds=\(powerline.birds.count), span_width=\(format(powerline.spanWidth)), support_count=\(powerline.supportCount), avg_bird_distance=\(format(powerline.averageBirdDistance)), continuity_ratio=\(format(powerline.continuityRatio)), maximum_gap_ratio=\(format(powerline.maximumGapRatio)), average_alignment_error=\(format(powerline.averageAlignmentError)), residual_line_thickness=\(format(powerline.residualLineThickness)), average_support_thickness=\(format(powerline.averageSupportThickness)), centrality=\(format(powerline.centralityScore))"
    }

    private func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func log(_ message: String) {
        logHandler("[NoteGeneratorModule] \(message)")
    }
}
