//
//  PerchNotesTests.swift
//  PerchNotesTests
//
//  Created by TJ and Brianna Olsen on 4/5/26.
//

import Testing
@testable import PerchNotes

struct PerchNotesTests {
    @Test
    func imageProviderReturnsDeterministicSourceImageForSelection() {
        let module = ImageProviderModule()

        let output = module.provideImage(
            image_acquisition_request: ImageAcquisitionRequest(acquisition_method: .SELECT_EXISTING_IMAGE),
            camera_permission_state: CameraPermissionState(state: .DENIED)
        )

        #expect(output.image_acquisition_result.status == .SUCCESS)
        #expect(output.image_acquisition_result.reason == nil)
        #expect(output.source_image?.image_id == "stub-image-select-existing-image")
        #expect(output.source_image?.origin_method == .SELECT_EXISTING_IMAGE)
        #expect(output.source_image?.image_reference == "stub://image/select-existing-image")
    }

    @Test
    func imageProviderFailsWhenCapturePermissionIsNotGranted() {
        let module = ImageProviderModule()

        let output = module.provideImage(
            image_acquisition_request: ImageAcquisitionRequest(acquisition_method: .CAPTURE_NEW_IMAGE),
            camera_permission_state: CameraPermissionState(state: .DENIED)
        )

        #expect(output.source_image == nil)
        #expect(output.image_acquisition_result.status == .FAILED)
        #expect(output.image_acquisition_result.reason == .CAMERA_PERMISSION_REQUIRED)
    }

    @Test
    func noteGeneratorReturnsDeterministicSequenceForSameSourceImage() {
        let module = NoteGeneratorModule()
        let sourceImage = SourceImage(
            image_id: "stub-image-select-existing-image",
            origin_method: .SELECT_EXISTING_IMAGE,
            image_reference: "stub://image/select-existing-image"
        )

        let firstOutput = module.generateNotes(
            source_image: sourceImage,
            note_generation_request: NoteGenerationRequest(request_id: "request-1")
        )
        let secondOutput = module.generateNotes(
            source_image: sourceImage,
            note_generation_request: NoteGenerationRequest(request_id: "request-2")
        )

        #expect(firstOutput.note_generation_result.status == .SUCCESS)
        #expect(firstOutput.note_generation_result.reason == nil)
        #expect(firstOutput.note_sequence == secondOutput.note_sequence)
        #expect(firstOutput.note_sequence?.events.count == firstOutput.note_sequence?.note_count)
        #expect(firstOutput.note_sequence?.events.indices.allSatisfy { index in
            guard let event = firstOutput.note_sequence?.events[index] else {
                return false
            }
            return event.order_index == index
                && event.start_offset_units == index
                && event.duration_units == 1
        } == true)
    }

    @Test
    func noteGeneratorFailsWhenImageReferenceIsEmpty() {
        let module = NoteGeneratorModule()
        let sourceImage = SourceImage(
            image_id: "stub-image-invalid",
            origin_method: .SELECT_EXISTING_IMAGE,
            image_reference: "   "
        )

        let output = module.generateNotes(
            source_image: sourceImage,
            note_generation_request: NoteGenerationRequest(request_id: "request-empty-reference")
        )

        #expect(output.note_sequence == nil)
        #expect(output.note_generation_result.status == .FAILED)
        #expect(output.note_generation_result.reason == .IMAGE_ANALYSIS_FAILED)
    }

    @Test
    func audioGeneratorReturnsLoopableGeneratedAudioForValidSequence() {
        let module = AudioGeneratorModule()
        let noteSequence = NoteSequence(
            source_image_id: "stub-image-select-existing-image",
            note_count: 3,
            events: [
                NoteEvent(order_index: 0, pitch_rank: 1, start_offset_units: 0, duration_units: 1),
                NoteEvent(order_index: 1, pitch_rank: 2, start_offset_units: 1, duration_units: 1),
                NoteEvent(order_index: 2, pitch_rank: 3, start_offset_units: 2, duration_units: 1),
            ]
        )

        let output = module.generateAudio(
            note_sequence: noteSequence,
            audio_generation_request: AudioGenerationRequest(request_id: "audio-request-1")
        )

        #expect(output.audio_generation_result.status == .SUCCESS)
        #expect(output.audio_generation_result.reason == nil)
        #expect(output.generated_audio?.source_image_id == noteSequence.source_image_id)
        #expect(output.generated_audio?.note_count == noteSequence.note_count)
        #expect(output.generated_audio?.loopable == true)
        #expect(output.generated_audio?.audio_reference == "stub://audio/stub-image-select-existing-image/3")
    }

    @Test
    func audioGeneratorFailsWhenTimingIsInvalid() {
        let module = AudioGeneratorModule()
        let invalidSequence = NoteSequence(
            source_image_id: "stub-image-select-existing-image",
            note_count: 2,
            events: [
                NoteEvent(order_index: 0, pitch_rank: 1, start_offset_units: 0, duration_units: 1),
                NoteEvent(order_index: 1, pitch_rank: 2, start_offset_units: 4, duration_units: 1),
            ]
        )

        let output = module.generateAudio(
            note_sequence: invalidSequence,
            audio_generation_request: AudioGenerationRequest(request_id: "audio-request-invalid")
        )

        #expect(output.generated_audio == nil)
        #expect(output.audio_generation_result.status == .FAILED)
        #expect(output.audio_generation_result.reason == .INVALID_NOTE_TIMING)
    }
}
