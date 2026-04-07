//
//  CorePipelineModels.swift
//  PerchNotes
//
//  Created by Codex on 4/6/26.
//

import Foundation

enum CorePipelineStatus: String, Sendable {
    case SUCCESS
    case FAILED
}

struct CorePipelineRequest: Sendable, Equatable {
    let image_acquisition_request: ImageAcquisitionRequest
    let camera_permission_state: CameraPermissionState
}

struct CorePipelineImageAcquisitionOutcome: Sendable, Equatable {
    let source_image: SourceImage?
    let image_acquisition_result: ImageAcquisitionResult
}

struct CorePipelineNoteGenerationOutcome: Sendable, Equatable {
    let note_sequence: NoteSequence?
    let note_generation_result: NoteGenerationResult
}

struct CorePipelineAudioGenerationOutcome: Sendable, Equatable {
    let generated_audio: GeneratedAudio?
    let audio_generation_result: AudioGenerationResult
}

struct CorePipelineResult: Sendable, Equatable {
    let image_acquisition_outcome: CorePipelineImageAcquisitionOutcome
    let note_generation_outcome: CorePipelineNoteGenerationOutcome?
    let audio_generation_outcome: CorePipelineAudioGenerationOutcome?
    let final_pipeline_status: CorePipelineStatus
}
