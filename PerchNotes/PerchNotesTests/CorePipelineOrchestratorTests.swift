//
//  CorePipelineOrchestratorTests.swift
//  PerchNotesTests
//
//  Created by Codex on 4/6/26.
//

import Testing
@testable import PerchNotes

struct CorePipelineOrchestratorTests {
    @Test
    func pipelineSucceedsWhenAllStubModulesSucceed() {
        let logger = LogCollector()
        let orchestrator = CorePipelineOrchestrator(
            imageProvider: ImageProviderModule(),
            noteGenerator: NoteGeneratorModule(),
            audioGenerator: AudioGeneratorModule(),
            logHandler: logger.record
        )

        let result = orchestrator.runPipeline(
            request: CorePipelineRequest(
                image_acquisition_request: ImageAcquisitionRequest(acquisition_method: .SELECT_EXISTING_IMAGE),
                camera_permission_state: CameraPermissionState(state: .DENIED)
            )
        )

        #expect(result.final_pipeline_status == .SUCCESS)
        #expect(result.image_acquisition_outcome.image_acquisition_result.status == .SUCCESS)
        #expect(result.note_generation_outcome?.note_generation_result.status == .SUCCESS)
        #expect(result.audio_generation_outcome?.audio_generation_result.status == .SUCCESS)
        #expect(result.image_acquisition_outcome.source_image?.image_id == "stub-image-select-existing-image")
        #expect(result.note_generation_outcome?.note_sequence?.source_image_id == "stub-image-select-existing-image")
        #expect(result.audio_generation_outcome?.generated_audio?.source_image_id == "stub-image-select-existing-image")
        #expect(result.audio_generation_outcome?.generated_audio?.loopable == true)
        #expect(logger.messages.contains(where: { $0.contains("pipeline started") }))
        #expect(logger.messages.contains(where: { $0.contains("image acquisition started") }))
        #expect(logger.messages.contains(where: { $0.contains("image acquisition result") }))
        #expect(logger.messages.contains(where: { $0.contains("note generation started") }))
        #expect(logger.messages.contains(where: { $0.contains("note generation result") }))
        #expect(logger.messages.contains(where: { $0.contains("audio generation started") }))
        #expect(logger.messages.contains(where: { $0.contains("audio generation result") }))
        #expect(logger.messages.contains(where: { $0.contains("pipeline success") }))
    }

    @Test
    func pipelineStopsWhenImageAcquisitionFails() {
        let noteGenerator = TrackingNoteGenerator(output: .success)
        let audioGenerator = TrackingAudioGenerator(output: .success)
        let orchestrator = CorePipelineOrchestrator(
            imageProvider: ImageProviderModule(),
            noteGenerator: noteGenerator,
            audioGenerator: audioGenerator,
            logHandler: { _ in }
        )

        let result = orchestrator.runPipeline(
            request: CorePipelineRequest(
                image_acquisition_request: ImageAcquisitionRequest(acquisition_method: .CAPTURE_NEW_IMAGE),
                camera_permission_state: CameraPermissionState(state: .DENIED)
            )
        )

        #expect(result.final_pipeline_status == .FAILED)
        #expect(result.image_acquisition_outcome.image_acquisition_result.reason == .CAMERA_PERMISSION_REQUIRED)
        #expect(result.note_generation_outcome == nil)
        #expect(result.audio_generation_outcome == nil)
        #expect(noteGenerator.callCount == 0)
        #expect(audioGenerator.callCount == 0)
    }

    @Test
    func pipelineStopsWhenNoteGenerationFails() {
        let noteGenerator = TrackingNoteGenerator(output: .failure(.IMAGE_ANALYSIS_FAILED))
        let audioGenerator = TrackingAudioGenerator(output: .success)
        let orchestrator = CorePipelineOrchestrator(
            imageProvider: ImageProviderModule(),
            noteGenerator: noteGenerator,
            audioGenerator: audioGenerator,
            logHandler: { _ in }
        )

        let result = orchestrator.runPipeline(
            request: CorePipelineRequest(
                image_acquisition_request: ImageAcquisitionRequest(acquisition_method: .SELECT_EXISTING_IMAGE),
                camera_permission_state: CameraPermissionState(state: .UNKNOWN)
            )
        )

        #expect(result.final_pipeline_status == .FAILED)
        #expect(result.image_acquisition_outcome.image_acquisition_result.status == .SUCCESS)
        #expect(result.note_generation_outcome?.note_generation_result.status == .FAILED)
        #expect(result.note_generation_outcome?.note_generation_result.reason == .IMAGE_ANALYSIS_FAILED)
        #expect(result.audio_generation_outcome == nil)
        #expect(noteGenerator.callCount == 1)
        #expect(audioGenerator.callCount == 0)
    }

    @Test
    func pipelineStopsWhenAudioGenerationFails() {
        let noteGenerator = TrackingNoteGenerator(output: .success)
        let audioGenerator = TrackingAudioGenerator(output: .failure(.AUDIO_GENERATION_FAILED))
        let orchestrator = CorePipelineOrchestrator(
            imageProvider: ImageProviderModule(),
            noteGenerator: noteGenerator,
            audioGenerator: audioGenerator,
            logHandler: { _ in }
        )

        let result = orchestrator.runPipeline(
            request: CorePipelineRequest(
                image_acquisition_request: ImageAcquisitionRequest(acquisition_method: .SELECT_EXISTING_IMAGE),
                camera_permission_state: CameraPermissionState(state: .UNKNOWN)
            )
        )

        #expect(result.final_pipeline_status == .FAILED)
        #expect(result.image_acquisition_outcome.image_acquisition_result.status == .SUCCESS)
        #expect(result.note_generation_outcome?.note_generation_result.status == .SUCCESS)
        #expect(result.audio_generation_outcome?.audio_generation_result.status == .FAILED)
        #expect(result.audio_generation_outcome?.audio_generation_result.reason == .AUDIO_GENERATION_FAILED)
        #expect(noteGenerator.callCount == 1)
        #expect(audioGenerator.callCount == 1)
    }
}

private final class LogCollector {
    private(set) var messages: [String] = []

    func record(_ message: String) {
        messages.append(message)
    }
}

private final class TrackingNoteGenerator: NoteGenerator {
    enum Output {
        case success
        case failure(NoteGenerationFailureReason)
    }

    private(set) var callCount = 0
    private let output: Output

    init(output: Output) {
        self.output = output
    }

    func generateNotes(
        source_image: SourceImage,
        note_generation_request: NoteGenerationRequest
    ) -> (note_sequence: NoteSequence?, note_generation_result: NoteGenerationResult) {
        callCount += 1

        switch output {
        case .success:
            let noteSequence = NoteSequence(
                source_image_id: source_image.image_id,
                note_count: 2,
                events: [
                    NoteEvent(order_index: 0, pitch_rank: 2, start_offset_units: 0, duration_units: 1),
                    NoteEvent(order_index: 1, pitch_rank: 1, start_offset_units: 1, duration_units: 1),
                ]
            )
            return (
                noteSequence,
                NoteGenerationResult(status: .SUCCESS, reason: nil)
            )

        case .failure(let reason):
            return (
                nil,
                NoteGenerationResult(status: .FAILED, reason: reason)
            )
        }
    }
}

private final class TrackingAudioGenerator: AudioGenerator {
    enum Output {
        case success
        case failure(AudioGenerationFailureReason)
    }

    private(set) var callCount = 0
    private let output: Output

    init(output: Output) {
        self.output = output
    }

    func generateAudio(
        note_sequence: NoteSequence,
        audio_generation_request: AudioGenerationRequest
    ) -> (generated_audio: GeneratedAudio?, audio_generation_result: AudioGenerationResult) {
        callCount += 1

        switch output {
        case .success:
            let generatedAudio = GeneratedAudio(
                audio_id: "tracked-audio-\(note_sequence.source_image_id)",
                source_image_id: note_sequence.source_image_id,
                note_count: note_sequence.note_count,
                loopable: true,
                audio_reference: "stub://audio/tracked/\(note_sequence.source_image_id)"
            )
            return (
                generatedAudio,
                AudioGenerationResult(status: .SUCCESS, reason: nil)
            )

        case .failure(let reason):
            return (
                nil,
                AudioGenerationResult(status: .FAILED, reason: reason)
            )
        }
    }
}
