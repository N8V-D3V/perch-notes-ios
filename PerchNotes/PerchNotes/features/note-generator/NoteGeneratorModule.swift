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
    let intercept: Double
    let minX: Double
    let maxX: Double
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
        intercept: Double = 0,
        minX: Double = 0,
        maxX: Double = 0,
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
        self.intercept = intercept
        self.minX = minX
        self.maxX = maxX
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

    func yPosition(atX x: Double) -> Double {
        (slope * x) + intercept
    }
}

struct DetectedBird {
    let centerX: Double
    let centerY: Double
    let darknessScore: Double
}

struct NoteGeneratorModule: NoteGenerator {
    private struct MergedBirdObservation {
        let centerX: Double
        let centerY: Double
        let darknessScore: Double
    }

    private struct AssignedBird {
        let centerX: Double
        let centerY: Double
        let lineIndex: Int
        let pitchRank: Int
    }

    private struct SelectedPowerlineAssignment {
        let powerline: DetectedPowerline
        let lineIndex: Int
        let pitchRank: Int
        let birds: [DetectedBird]
    }

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
            log("intended behavior: analyze one source image, select one to seven valid powerlines, assign birds to those lines, group them into deterministic left-to-right time steps, and map them into monophonic or polyphonic note events")
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

                let prioritizedPowerlines = prioritizePowerlines(detectedPowerlines)
                let canonicalPowerlines = canonicalizePowerlines(prioritizedPowerlines)
                let selectedPowerlines = Array(canonicalPowerlines.prefix(7))
                log("line selection behavior: canonical_count=\(canonicalPowerlines.count), selected_count=\(selectedPowerlines.count)")

                guard selectedPowerlines.isEmpty == false else {
                    let failure = NoteGenerationResult(status: .FAILED, reason: .NO_VALID_POWERLINE)
                    log("decision path: no valid powerlines remained after deterministic ranking")
                    log("output produced: note_sequence=nil, note_generation_result=\(describe(failure))")
                    return (nil, failure)
                }

                guard let orderedSelectedPowerlines = orderSelectedPowerlinesTopToBottom(selectedPowerlines) else {
                    let failure = NoteGenerationResult(status: .FAILED, reason: .AMBIGUOUS_NOTE_ORDER)
                    log("decision path: selected powerlines could not be ordered top-to-bottom deterministically")
                    log("output produced: note_sequence=nil, note_generation_result=\(describe(failure))")
                    return (nil, failure)
                }

                logSelectedPowerlines(orderedSelectedPowerlines)

                let birdObservations = makeBirdObservations(from: orderedSelectedPowerlines)
                log(
                    "bird association input: raw_bird_count=\(orderedSelectedPowerlines.reduce(0) { $0 + $1.birds.count }), observation_count=\(birdObservations.count)"
                )

                let assignedBirdsByLine = associateBirds(
                    birdObservations,
                    to: orderedSelectedPowerlines
                )
                logBirdAssociationSummary(assignedBirdsByLine, orderedSelectedPowerlines: orderedSelectedPowerlines)

                let representedAssignments = makeSelectedPowerlineAssignments(
                    from: orderedSelectedPowerlines,
                    assignedBirdsByLine: assignedBirdsByLine
                )

                guard representedAssignments.isEmpty == false else {
                    let failure = NoteGenerationResult(status: .FAILED, reason: .NO_BIRDS_DETECTED)
                    log("decision path: no birds remained assigned to the selected powerlines")
                    log("output produced: note_sequence=nil, note_generation_result=\(describe(failure))")
                    return (nil, failure)
                }

                guard let events = makePolyphonicNoteEvents(from: representedAssignments) else {
                    let failure = NoteGenerationResult(status: .FAILED, reason: .AMBIGUOUS_NOTE_ORDER)
                    log("decision path: bird grouping could not produce a deterministic left-to-right event order")
                    log("output produced: note_sequence=nil, note_generation_result=\(describe(failure))")
                    return (nil, failure)
                }
                let noteSequence = NoteSequence(
                    source_image_id: source_image.image_id,
                    line_count: representedAssignments.count,
                    note_count: events.count,
                    events: events
                )
                let success = NoteGenerationResult(status: .SUCCESS, reason: nil)

                log("generated sequence summary: line_count=\(noteSequence.line_count), note_count=\(noteSequence.note_count)")
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

    private func prioritizePowerlines(_ detectedPowerlines: [DetectedPowerline]) -> [DetectedPowerline] {
        detectedPowerlines.sorted(by: compareSelectionPriority)
    }

    private func canonicalizePowerlines(_ prioritizedPowerlines: [DetectedPowerline]) -> [DetectedPowerline] {
        let coarseDeduplicated = coarseDeduplicatePowerlines(prioritizedPowerlines)
        let mergedLayers = mergeNearbyPowerlineLayers(coarseDeduplicated)
        return mergedLayers.sorted(by: compareSelectionPriority)
    }

    private func coarseDeduplicatePowerlines(_ prioritizedPowerlines: [DetectedPowerline]) -> [DetectedPowerline] {
        var canonical: [DetectedPowerline] = []

        for candidate in prioritizedPowerlines {
            let isDuplicate = canonical.contains { existing in
                isDuplicatePowerlineCandidate(candidate, comparedTo: existing)
            }

            if isDuplicate == false {
                canonical.append(candidate)
            }
        }

        return canonical
    }

    private func mergeNearbyPowerlineLayers(_ powerlines: [DetectedPowerline]) -> [DetectedPowerline] {
        let orderedByHeight = powerlines.sorted { lhs, rhs in
            if abs(lhs.centerY - rhs.centerY) >= 0.0001 {
                return lhs.centerY < rhs.centerY
            }
            return lhs.intercept < rhs.intercept
        }

        var clusters: [[DetectedPowerline]] = []

        for powerline in orderedByHeight {
            if let index = clusters.indices.last(where: { clusterIndex in
                shouldMergeIntoExistingLayer(powerline, cluster: clusters[clusterIndex])
            }) {
                clusters[index].append(powerline)
            } else {
                clusters.append([powerline])
            }
        }

        return clusters.map(mergePowerlineLayer)
    }

    private func shouldMergeIntoExistingLayer(
        _ candidate: DetectedPowerline,
        cluster: [DetectedPowerline]
    ) -> Bool {
        guard let representative = cluster.sorted(by: compareSelectionPriority).first else {
            return false
        }

        let verticalBandThreshold = 2.8
        let overlap = horizontalOverlapRatio(candidate, representative)
        let birdOverlap = birdOverlapRatio(candidate, representative)

        return abs(candidate.centerY - representative.centerY) <= verticalBandThreshold
            && (overlap >= 0.7 || birdOverlap >= 0.25)
    }

    private func horizontalOverlapRatio(_ lhs: DetectedPowerline, _ rhs: DetectedPowerline) -> Double {
        let overlapWidth = max(0.0, min(lhs.maxX, rhs.maxX) - max(lhs.minX, rhs.minX))
        let minimumWidth = max(1.0, min(lhs.spanWidth, rhs.spanWidth))
        return overlapWidth / minimumWidth
    }

    private func mergePowerlineLayer(_ cluster: [DetectedPowerline]) -> DetectedPowerline {
        let representative = cluster.sorted(by: compareSelectionPriority).first ?? cluster[0]
        let totalWeight = cluster.reduce(0.0) { partial, powerline in
            partial + powerlineLayerWeight(powerline)
        }

        func weightedAverage(_ value: (DetectedPowerline) -> Double) -> Double {
            guard totalWeight > 0 else {
                return value(representative)
            }
            return cluster.reduce(0.0) { partial, powerline in
                partial + (value(powerline) * powerlineLayerWeight(powerline))
            } / totalWeight
        }

        let mergedBirds = mergeBirdsWithinLayer(cluster.flatMap(\.birds))
        let mergedMinX = cluster.map(\.minX).min() ?? representative.minX
        let mergedMaxX = cluster.map(\.maxX).max() ?? representative.maxX
        let mergedSupportCount = cluster.map(\.supportCount).max() ?? representative.supportCount
        let mergedProminence =
            (Double(mergedBirds.count) * 100_000.0)
            + ((mergedMaxX - mergedMinX) * 200.0)
            + (Double(mergedSupportCount) * 20.0)
            + (weightedAverage(\.continuityRatio) * 900.0)
            + (weightedAverage(\.centralityScore) * 10.0)
            - (weightedAverage(\.averageBirdDistance) * 50.0)
            - (weightedAverage(\.residualLineThickness) * 200.0)
            - (weightedAverage(\.averageSupportThickness) * 250.0)
            - (weightedAverage(\.maximumGapRatio) * 950.0)
            - (weightedAverage(\.averageAlignmentError) * 280.0)

        return DetectedPowerline(
            intercept: weightedAverage(\.intercept),
            minX: mergedMinX,
            maxX: mergedMaxX,
            centerY: weightedAverage(\.centerY),
            prominenceScore: mergedProminence,
            birds: mergedBirds,
            slope: weightedAverage(\.slope),
            spanWidth: mergedMaxX - mergedMinX,
            supportCount: mergedSupportCount,
            averageBirdDistance: weightedAverage(\.averageBirdDistance),
            centralityScore: weightedAverage(\.centralityScore),
            residualLineThickness: weightedAverage(\.residualLineThickness),
            averageSupportThickness: weightedAverage(\.averageSupportThickness),
            continuityRatio: weightedAverage(\.continuityRatio),
            maximumGapRatio: weightedAverage(\.maximumGapRatio),
            averageAlignmentError: weightedAverage(\.averageAlignmentError)
        )
    }

    private func powerlineLayerWeight(_ powerline: DetectedPowerline) -> Double {
        max(1.0, Double(powerline.birds.count * 10) + powerline.spanWidth + Double(powerline.supportCount))
    }

    private func mergeBirdsWithinLayer(_ birds: [DetectedBird]) -> [DetectedBird] {
        let sortedBirds = birds.sorted { lhs, rhs in
            if abs(lhs.centerX - rhs.centerX) >= 0.0001 {
                return lhs.centerX < rhs.centerX
            }
            if abs(lhs.centerY - rhs.centerY) >= 0.0001 {
                return lhs.centerY < rhs.centerY
            }
            return lhs.darknessScore > rhs.darknessScore
        }

        var clusters: [[DetectedBird]] = []
        for bird in sortedBirds {
            if let index = clusters.firstIndex(where: { cluster in
                guard let anchor = cluster.first else {
                    return false
                }
                return abs(anchor.centerX - bird.centerX) <= 6.0
                    && abs(anchor.centerY - bird.centerY) <= 5.0
            }) {
                clusters[index].append(bird)
            } else {
                clusters.append([bird])
            }
        }

        return clusters.map { cluster in
            let darknessTotal = cluster.reduce(0.0) { $0 + $1.darknessScore }
            let weightedCenterX = cluster.reduce(0.0) { $0 + ($1.centerX * $1.darknessScore) }
            let weightedCenterY = cluster.reduce(0.0) { $0 + ($1.centerY * $1.darknessScore) }
            return DetectedBird(
                centerX: darknessTotal == 0 ? cluster[0].centerX : weightedCenterX / darknessTotal,
                centerY: darknessTotal == 0 ? cluster[0].centerY : weightedCenterY / darknessTotal,
                darknessScore: darknessTotal == 0 ? cluster[0].darknessScore : darknessTotal
            )
        }
    }

    private func isDuplicatePowerlineCandidate(
        _ candidate: DetectedPowerline,
        comparedTo existing: DetectedPowerline
    ) -> Bool {
        let birdOverlap = birdOverlapRatio(candidate, existing)
        let nearlyIdenticalGeometry =
            abs(candidate.intercept - existing.intercept) <= 10.0
            && abs(candidate.slope - existing.slope) <= 0.03
        let tightlyAlignedGeometry =
            abs(candidate.centerY - existing.centerY) <= 3.0
            && abs(candidate.intercept - existing.intercept) <= 10.0
            && abs(candidate.slope - existing.slope) <= 0.06
        let overlappingGeometry =
            abs(candidate.intercept - existing.intercept) <= 12.0
            && abs(candidate.slope - existing.slope) <= 0.08

        return nearlyIdenticalGeometry
            || (tightlyAlignedGeometry && birdOverlap >= 0.5)
            || (overlappingGeometry && birdOverlap >= 0.75)
    }

    private func birdOverlapRatio(_ lhs: DetectedPowerline, _ rhs: DetectedPowerline) -> Double {
        let smaller = lhs.birds.count <= rhs.birds.count ? lhs.birds : rhs.birds
        let larger = lhs.birds.count <= rhs.birds.count ? rhs.birds : lhs.birds
        guard smaller.isEmpty == false else {
            return 0
        }

        let overlapCount = smaller.reduce(0) { partial, bird in
            let hasMatch = larger.contains { otherBird in
                abs(bird.centerX - otherBird.centerX) <= 12.0
            }
            return partial + (hasMatch ? 1 : 0)
        }

        return Double(overlapCount) / Double(smaller.count)
    }

    private func compareSelectionPriority(_ lhs: DetectedPowerline, _ rhs: DetectedPowerline) -> Bool {
        if lhs.birds.count != rhs.birds.count {
            return lhs.birds.count > rhs.birds.count
        }

        if abs(lhs.spanWidth - rhs.spanWidth) >= 0.0001 {
            return lhs.spanWidth > rhs.spanWidth
        }

        let lhsQuality = lineQualityScore(for: lhs)
        let rhsQuality = lineQualityScore(for: rhs)
        if abs(lhsQuality - rhsQuality) >= 0.0001 {
            return lhsQuality > rhsQuality
        }

        if lhs.supportCount != rhs.supportCount {
            return lhs.supportCount > rhs.supportCount
        }

        if abs(lhs.averageBirdDistance - rhs.averageBirdDistance) >= 0.0001 {
            return lhs.averageBirdDistance < rhs.averageBirdDistance
        }

        if abs(lhs.centralityScore - rhs.centralityScore) >= 0.0001 {
            return lhs.centralityScore > rhs.centralityScore
        }

        if abs(lhs.prominenceScore - rhs.prominenceScore) >= 0.0001 {
            return lhs.prominenceScore > rhs.prominenceScore
        }

        if abs(abs(lhs.slope) - abs(rhs.slope)) >= 0.0001 {
            return abs(lhs.slope) < abs(rhs.slope)
        }

        return lhs.centerY < rhs.centerY
    }

    private func lineQualityScore(for powerline: DetectedPowerline) -> Double {
        (powerline.continuityRatio * 1_000.0)
            - (powerline.maximumGapRatio * 900.0)
            - (powerline.averageAlignmentError * 240.0)
            - (powerline.residualLineThickness * 180.0)
            - (powerline.averageSupportThickness * 220.0)
    }

    private func orderSelectedPowerlinesTopToBottom(_ powerlines: [DetectedPowerline]) -> [DetectedPowerline]? {
        let ordered = powerlines.sorted { lhs, rhs in
            if abs(lhs.centerY - rhs.centerY) >= 0.0001 {
                return lhs.centerY < rhs.centerY
            }

            if abs(lhs.intercept - rhs.intercept) >= 0.0001 {
                return lhs.intercept < rhs.intercept
            }

            if abs(lhs.slope - rhs.slope) >= 0.0001 {
                return lhs.slope < rhs.slope
            }

            return compareSelectionPriority(lhs, rhs)
        }

        for pair in zip(ordered, ordered.dropFirst()) {
            let upper = pair.0
            let lower = pair.1
            if abs(upper.centerY - lower.centerY) < 0.5
                && abs(upper.intercept - lower.intercept) < 0.5
                && abs(upper.slope - lower.slope) < 0.005 {
                log(
                    "line ordering ambiguity: adjacent selected lines remained indistinguishable. upper=\(describeSelection(upper)); lower=\(describeSelection(lower))"
                )
                return nil
            }
        }

        return ordered
    }

    private func makeBirdObservations(from powerlines: [DetectedPowerline]) -> [MergedBirdObservation] {
        powerlines
            .flatMap(\.birds)
            .map { bird in
                MergedBirdObservation(
                    centerX: bird.centerX,
                    centerY: bird.centerY,
                    darknessScore: bird.darknessScore
                )
            }
            .sorted { lhs, rhs in
            if abs(lhs.centerX - rhs.centerX) >= 0.0001 {
                return lhs.centerX < rhs.centerX
            }

            if abs(lhs.centerY - rhs.centerY) >= 0.0001 {
                return lhs.centerY < rhs.centerY
            }
                return lhs.darknessScore > rhs.darknessScore
            }
    }

    private func associateBirds(
        _ birds: [MergedBirdObservation],
        to orderedSelectedPowerlines: [DetectedPowerline]
    ) -> [Int: [DetectedBird]] {
        let verticalAssignmentThreshold = makeVerticalAssignmentThreshold(for: orderedSelectedPowerlines)
        var assignedBirdsByLine: [Int: [DetectedBird]] = [:]

        for bird in birds {
            var bestMatch: (lineIndex: Int, distance: Double)?

            for (lineIndex, powerline) in orderedSelectedPowerlines.enumerated() {
                let horizontalPadding = max(10.0, powerline.spanWidth * 0.04)
                guard bird.centerX >= powerline.minX - horizontalPadding,
                      bird.centerX <= powerline.maxX + horizontalPadding else {
                    continue
                }

                let verticalDistance = abs(bird.centerY - powerline.yPosition(atX: bird.centerX))
                guard verticalDistance <= verticalAssignmentThreshold else {
                    continue
                }

                if let currentBest = bestMatch {
                    if verticalDistance < currentBest.distance - 0.0001
                        || (abs(verticalDistance - currentBest.distance) < 0.0001 && lineIndex < currentBest.lineIndex) {
                        bestMatch = (lineIndex, verticalDistance)
                    }
                } else {
                    bestMatch = (lineIndex, verticalDistance)
                }
            }

            guard let bestMatch else {
                continue
            }

            assignedBirdsByLine[bestMatch.lineIndex, default: []].append(
                DetectedBird(
                    centerX: bird.centerX,
                    centerY: bird.centerY,
                    darknessScore: bird.darknessScore
                )
            )
        }

        return assignedBirdsByLine.mapValues { birds in
            mergeAssignedBirdsWithinLine(birds)
        }
    }

    private func mergeAssignedBirdsWithinLine(_ birds: [DetectedBird]) -> [DetectedBird] {
        let sortedBirds = birds.sorted { lhs, rhs in
            if abs(lhs.centerX - rhs.centerX) >= 0.0001 {
                return lhs.centerX < rhs.centerX
            }

            if abs(lhs.centerY - rhs.centerY) >= 0.0001 {
                return lhs.centerY < rhs.centerY
            }

            return lhs.darknessScore > rhs.darknessScore
        }

        var clusters: [[DetectedBird]] = []
        for bird in sortedBirds {
            if let index = clusters.firstIndex(where: { cluster in
                guard let anchor = cluster.first else {
                    return false
                }

                return abs(anchor.centerX - bird.centerX) <= 4.5
                    && abs(anchor.centerY - bird.centerY) <= 4.0
            }) {
                clusters[index].append(bird)
            } else {
                clusters.append([bird])
            }
        }

        return clusters.map { cluster in
            let darknessTotal = cluster.reduce(0.0) { $0 + $1.darknessScore }
            let weightedCenterX = cluster.reduce(0.0) { $0 + ($1.centerX * $1.darknessScore) }
            let weightedCenterY = cluster.reduce(0.0) { $0 + ($1.centerY * $1.darknessScore) }
            return DetectedBird(
                centerX: darknessTotal == 0 ? cluster[0].centerX : weightedCenterX / darknessTotal,
                centerY: darknessTotal == 0 ? cluster[0].centerY : weightedCenterY / darknessTotal,
                darknessScore: darknessTotal == 0 ? cluster[0].darknessScore : darknessTotal
            )
        }
    }

    private func makeVerticalAssignmentThreshold(for orderedSelectedPowerlines: [DetectedPowerline]) -> Double {
        let centerYGaps = zip(orderedSelectedPowerlines, orderedSelectedPowerlines.dropFirst()).map { pair in
            abs(pair.1.centerY - pair.0.centerY)
        }
        let minimumGap = centerYGaps.min()
        let averageBirdDistance = orderedSelectedPowerlines.map(\.averageBirdDistance).reduce(0.0, +) / Double(max(orderedSelectedPowerlines.count, 1))

        return max(
            8.0,
            min(
                18.0,
                max(
                    (minimumGap ?? 18.0) * 0.42,
                    averageBirdDistance + 5.0
                )
            )
        )
    }

    private func makeSelectedPowerlineAssignments(
        from orderedSelectedPowerlines: [DetectedPowerline],
        assignedBirdsByLine: [Int: [DetectedBird]]
    ) -> [SelectedPowerlineAssignment] {
        let representedLineIndices = orderedSelectedPowerlines.indices.filter { index in
            (assignedBirdsByLine[index] ?? []).isEmpty == false
        }

        let lineCount = representedLineIndices.count
        return representedLineIndices.enumerated().map { offset, lineIndex in
            SelectedPowerlineAssignment(
                powerline: orderedSelectedPowerlines[lineIndex],
                lineIndex: lineIndex,
                pitchRank: lineCount - offset,
                birds: assignedBirdsByLine[lineIndex] ?? []
            )
        }
    }

    private func makePolyphonicNoteEvents(
        from selectedAssignments: [SelectedPowerlineAssignment]
    ) -> [NoteEvent]? {
        let assignedBirds = selectedAssignments.flatMap { assignment in
            assignment.birds.map { bird in
                AssignedBird(
                    centerX: bird.centerX,
                    centerY: bird.centerY,
                    lineIndex: assignment.lineIndex,
                    pitchRank: assignment.pitchRank
                )
            }
        }
        .sorted { lhs, rhs in
            if abs(lhs.centerX - rhs.centerX) >= 0.0001 {
                return lhs.centerX < rhs.centerX
            }

            if lhs.lineIndex != rhs.lineIndex {
                return lhs.lineIndex < rhs.lineIndex
            }

            return lhs.centerY < rhs.centerY
        }

        guard assignedBirds.isEmpty == false else {
            return []
        }

        let groupingThreshold = makeHorizontalGroupingThreshold(for: assignedBirds, selectedAssignments: selectedAssignments)
        var groupedBirdsByBucket: [Int: [AssignedBird]] = [:]
        for bird in assignedBirds {
            let bucket = Int(floor(bird.centerX / groupingThreshold))
            groupedBirdsByBucket[bucket, default: []].append(bird)
        }

        let groupedBirds = groupedBirdsByBucket.keys.sorted().compactMap { bucket in
            groupedBirdsByBucket[bucket]?.sorted { lhs, rhs in
                if lhs.lineIndex != rhs.lineIndex {
                    return lhs.lineIndex < rhs.lineIndex
                }
                return lhs.centerX < rhs.centerX
            }
        }

        let events = groupedBirds.enumerated().map { index, birds in
            let pitchRanks = Array(Set(birds.map(\.pitchRank))).sorted(by: >)
            return NoteEvent(
                order_index: index,
                pitch_ranks: pitchRanks,
                start_offset_units: index,
                duration_units: 1
            )
        }

        let groupSummaries = groupedBirds.enumerated().map { index, birds in
            let pitchRanks = Array(Set(birds.map(\.pitchRank))).sorted(by: >)
            return "#\(index + 1){x:\(format(birds[0].centerX)), pitches:\(pitchRanks)}"
        }.joined(separator: ", ")

        log(
            "time-step grouping summary: threshold=\(format(groupingThreshold)), group_count=\(groupedBirds.count), groups=[\(groupSummaries)]"
        )

        return events
    }

    private func makeHorizontalGroupingThreshold(
        for assignedBirds: [AssignedBird],
        selectedAssignments: [SelectedPowerlineAssignment]
    ) -> Double {
        let maximumSpanWidth = selectedAssignments.map { $0.powerline.spanWidth }.max() ?? assignedBirds.map(\.centerX).max() ?? 120.0
        return max(5.0, min(14.0, maximumSpanWidth / 24.0))
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
        "center_y=\(format(powerline.centerY)), slope=\(format(powerline.slope)), prominence=\(format(powerline.prominenceScore)), birds=\(powerline.birds.count), span_width=\(format(powerline.spanWidth)), support_count=\(powerline.supportCount), avg_bird_distance=\(format(powerline.averageBirdDistance)), continuity_ratio=\(format(powerline.continuityRatio)), maximum_gap_ratio=\(format(powerline.maximumGapRatio)), average_alignment_error=\(format(powerline.averageAlignmentError)), residual_line_thickness=\(format(powerline.residualLineThickness)), average_support_thickness=\(format(powerline.averageSupportThickness)), centrality=\(format(powerline.centralityScore)), intercept=\(format(powerline.intercept)), min_x=\(format(powerline.minX)), max_x=\(format(powerline.maxX))"
    }

    private func logSelectedPowerlines(_ powerlines: [DetectedPowerline]) {
        let descriptions = powerlines.enumerated().map { index, powerline in
            let provisionalPitchRank = powerlines.count - index
            return "#\(index + 1){pitch_rank:\(provisionalPitchRank), \(describeSelection(powerline))}"
        }.joined(separator: " | ")
        log("selected lines top-to-bottom: \(descriptions)")
    }

    private func logBirdAssociationSummary(
        _ assignedBirdsByLine: [Int: [DetectedBird]],
        orderedSelectedPowerlines: [DetectedPowerline]
    ) {
        let summary = orderedSelectedPowerlines.enumerated().map { index, powerline in
            let birds = assignedBirdsByLine[index] ?? []
            let centers = birds.map { format($0.centerX) }.joined(separator: ", ")
            return "#\(index + 1){center_y:\(format(powerline.centerY)), assigned_birds:\(birds.count), centers_x:[\(centers)]}"
        }.joined(separator: " | ")
        log("bird association summary: \(summary)")
    }

    private func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func log(_ message: String) {
        logHandler("[NoteGeneratorModule] \(message)")
    }
}
