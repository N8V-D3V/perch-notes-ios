//
//  CorePipelineOrchestrator.swift
//  PerchNotes
//
//  Created by Codex on 4/6/26.
//

import Foundation

struct CorePipelineOrchestrator {
    private let imageProvider: any ImageProvider
    private let noteGenerator: any NoteGenerator
    private let audioGenerator: any AudioGenerator
    private let logHandler: (String) -> Void

    init(
        imageProvider: any ImageProvider,
        noteGenerator: any NoteGenerator,
        audioGenerator: any AudioGenerator,
        logHandler: @escaping (String) -> Void = { print($0) }
    ) {
        self.imageProvider = imageProvider
        self.noteGenerator = noteGenerator
        self.audioGenerator = audioGenerator
        self.logHandler = logHandler
    }

    func runPipeline(request: CorePipelineRequest) -> CorePipelineResult {
        log(
            "pipeline started: acquisition_method=\(request.image_acquisition_request.acquisition_method.rawValue), camera_permission_state=\(request.camera_permission_state.state.rawValue)"
        )

        log("image acquisition started")
        let imageProviderOutput = imageProvider.provideImage(
            image_acquisition_request: request.image_acquisition_request,
            camera_permission_state: request.camera_permission_state
        )
        let imageOutcome = CorePipelineImageAcquisitionOutcome(
            source_image: imageProviderOutput.source_image,
            image_acquisition_result: imageProviderOutput.image_acquisition_result
        )
        log(
            "image acquisition result: status=\(imageOutcome.image_acquisition_result.status.rawValue), reason=\(imageOutcome.image_acquisition_result.reason?.rawValue ?? "nil"), source_image_id=\(imageOutcome.source_image?.image_id ?? "nil")"
        )

        guard imageOutcome.image_acquisition_result.status == .SUCCESS,
              let sourceImage = imageOutcome.source_image else {
            log(
                "pipeline failure: stage=image acquisition, reason=\(imageOutcome.image_acquisition_result.reason?.rawValue ?? "nil")"
            )
            return CorePipelineResult(
                image_acquisition_outcome: imageOutcome,
                note_generation_outcome: nil,
                audio_generation_outcome: nil,
                final_pipeline_status: .FAILED
            )
        }

        let noteRequest = makeNoteGenerationRequest(from: sourceImage)
        log("note generation started: request_id=\(noteRequest.request_id), source_image_id=\(sourceImage.image_id)")
        let noteGeneratorOutput = noteGenerator.generateNotes(
            source_image: sourceImage,
            note_generation_request: noteRequest
        )
        let noteOutcome = CorePipelineNoteGenerationOutcome(
            note_sequence: noteGeneratorOutput.note_sequence,
            note_generation_result: noteGeneratorOutput.note_generation_result
        )
        log(
            "note generation result: status=\(noteOutcome.note_generation_result.status.rawValue), reason=\(noteOutcome.note_generation_result.reason?.rawValue ?? "nil"), note_count=\(noteOutcome.note_sequence?.note_count.description ?? "nil")"
        )

        guard noteOutcome.note_generation_result.status == .SUCCESS,
              let noteSequence = noteOutcome.note_sequence else {
            log(
                "pipeline failure: stage=note generation, reason=\(noteOutcome.note_generation_result.reason?.rawValue ?? "nil")"
            )
            return CorePipelineResult(
                image_acquisition_outcome: imageOutcome,
                note_generation_outcome: noteOutcome,
                audio_generation_outcome: nil,
                final_pipeline_status: .FAILED
            )
        }

        let audioRequest = makeAudioGenerationRequest(from: noteSequence)
        log(
            "audio generation started: request_id=\(audioRequest.request_id), source_image_id=\(noteSequence.source_image_id), note_count=\(noteSequence.note_count)"
        )
        let audioGeneratorOutput = audioGenerator.generateAudio(
            note_sequence: noteSequence,
            audio_generation_request: audioRequest
        )
        let audioOutcome = CorePipelineAudioGenerationOutcome(
            generated_audio: audioGeneratorOutput.generated_audio,
            audio_generation_result: audioGeneratorOutput.audio_generation_result
        )
        log(
            "audio generation result: status=\(audioOutcome.audio_generation_result.status.rawValue), reason=\(audioOutcome.audio_generation_result.reason?.rawValue ?? "nil"), audio_id=\(audioOutcome.generated_audio?.audio_id ?? "nil")"
        )

        guard audioOutcome.audio_generation_result.status == .SUCCESS,
              let generatedAudio = audioOutcome.generated_audio else {
            log(
                "pipeline failure: stage=audio generation, reason=\(audioOutcome.audio_generation_result.reason?.rawValue ?? "nil")"
            )
            return CorePipelineResult(
                image_acquisition_outcome: imageOutcome,
                note_generation_outcome: noteOutcome,
                audio_generation_outcome: audioOutcome,
                final_pipeline_status: .FAILED
            )
        }

        log(
            "pipeline success: source_image_id=\(sourceImage.image_id), note_count=\(noteSequence.note_count), audio_id=\(generatedAudio.audio_id)"
        )
        return CorePipelineResult(
            image_acquisition_outcome: imageOutcome,
            note_generation_outcome: noteOutcome,
            audio_generation_outcome: audioOutcome,
            final_pipeline_status: .SUCCESS
        )
    }

    private func makeNoteGenerationRequest(from sourceImage: SourceImage) -> NoteGenerationRequest {
        NoteGenerationRequest(request_id: "core-pipeline-note-\(sourceImage.image_id)")
    }

    private func makeAudioGenerationRequest(from noteSequence: NoteSequence) -> AudioGenerationRequest {
        AudioGenerationRequest(request_id: "core-pipeline-audio-\(noteSequence.source_image_id)-\(noteSequence.note_count)")
    }

    private func log(_ message: String) {
        logHandler("[CorePipelineOrchestrator] \(message)")
    }
}
