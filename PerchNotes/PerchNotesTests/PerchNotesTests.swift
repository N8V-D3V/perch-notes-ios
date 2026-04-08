//
//  PerchNotesTests.swift
//  PerchNotesTests
//
//  Created by TJ and Brianna Olsen on 4/5/26.
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import PerchNotes

struct PerchNotesTests {
    @Test
    func imageProviderDemoCompatibleModeReturnsDeterministicSourceImageForSelection() {
        let module = ImageProviderModule(mode: .demoCompatible)

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
        let module = ImageProviderModule(mode: .demoCompatible)

        let output = module.provideImage(
            image_acquisition_request: ImageAcquisitionRequest(acquisition_method: .CAPTURE_NEW_IMAGE),
            camera_permission_state: CameraPermissionState(state: .DENIED)
        )

        #expect(output.source_image == nil)
        #expect(output.image_acquisition_result.status == .FAILED)
        #expect(output.image_acquisition_result.reason == .CAMERA_PERMISSION_REQUIRED)
    }

    @Test
    func imageProviderResponseDrivenModeReturnsStableImageForReadableFile() throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("perch-notes-image-provider-test-\(UUID().uuidString).img")
        try Data("bird-on-wire".utf8).write(to: tempFile, options: .atomic)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let responder = FixedImageAcquisitionResponder(
            response: ImageAcquisitionResponse(
                status: .COMPLETED,
                image_count: 1,
                image_reference: tempFile.absoluteString
            )
        )
        let module = ImageProviderModule(mode: .responseDriven(responder))

        let firstOutput = module.provideImage(
            image_acquisition_request: ImageAcquisitionRequest(acquisition_method: .SELECT_EXISTING_IMAGE),
            camera_permission_state: CameraPermissionState(state: .UNKNOWN)
        )
        let secondOutput = module.provideImage(
            image_acquisition_request: ImageAcquisitionRequest(acquisition_method: .SELECT_EXISTING_IMAGE),
            camera_permission_state: CameraPermissionState(state: .UNKNOWN)
        )

        #expect(firstOutput.image_acquisition_result.status == .SUCCESS)
        #expect(firstOutput.image_acquisition_result.reason == nil)
        #expect(firstOutput.source_image?.origin_method == .SELECT_EXISTING_IMAGE)
        #expect(firstOutput.source_image?.image_reference == tempFile.absoluteString)
        #expect(firstOutput.source_image?.image_id == secondOutput.source_image?.image_id)
    }

    @Test
    func imageProviderResponseDrivenModeFailsForCancelledAcquisition() {
        let responder = FixedImageAcquisitionResponder(
            response: ImageAcquisitionResponse(
                status: .CANCELLED,
                image_count: 0,
                image_reference: nil
            )
        )
        let module = ImageProviderModule(mode: .responseDriven(responder))

        let output = module.provideImage(
            image_acquisition_request: ImageAcquisitionRequest(acquisition_method: .SELECT_EXISTING_IMAGE),
            camera_permission_state: CameraPermissionState(state: .UNKNOWN)
        )

        #expect(output.source_image == nil)
        #expect(output.image_acquisition_result.status == .FAILED)
        #expect(output.image_acquisition_result.reason == .IMAGE_ACQUISITION_CANCELLED)
    }

    @Test
    func imageProviderResponseDrivenModeFailsForEmptyReference() {
        let responder = FixedImageAcquisitionResponder(
            response: ImageAcquisitionResponse(
                status: .COMPLETED,
                image_count: 1,
                image_reference: "   "
            )
        )
        let module = ImageProviderModule(mode: .responseDriven(responder))

        let output = module.provideImage(
            image_acquisition_request: ImageAcquisitionRequest(acquisition_method: .SELECT_EXISTING_IMAGE),
            camera_permission_state: CameraPermissionState(state: .UNKNOWN)
        )

        #expect(output.source_image == nil)
        #expect(output.image_acquisition_result.status == .FAILED)
        #expect(output.image_acquisition_result.reason == .INVALID_SOURCE_IMAGE)
    }

    @Test
    func imageProviderResponseDrivenModeFailsForMultipleImages() {
        let responder = FixedImageAcquisitionResponder(
            response: ImageAcquisitionResponse(
                status: .COMPLETED,
                image_count: 2,
                image_reference: "ignored"
            )
        )
        let module = ImageProviderModule(mode: .responseDriven(responder))

        let output = module.provideImage(
            image_acquisition_request: ImageAcquisitionRequest(acquisition_method: .SELECT_EXISTING_IMAGE),
            camera_permission_state: CameraPermissionState(state: .UNKNOWN)
        )

        #expect(output.source_image == nil)
        #expect(output.image_acquisition_result.status == .FAILED)
        #expect(output.image_acquisition_result.reason == .MULTIPLE_IMAGES_NOT_SUPPORTED)
    }

    @Test
    func noteGeneratorDemoCompatibleModeReturnsDeterministicSequenceForSameSourceImage() {
        let module = NoteGeneratorModule(mode: .demoCompatible)
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
        #expect(firstOutput.note_sequence?.line_count == 1)
        #expect(firstOutput.note_sequence?.events.count == firstOutput.note_sequence?.note_count)
        #expect(firstOutput.note_sequence?.events.indices.allSatisfy { index in
            guard let event = firstOutput.note_sequence?.events[index] else {
                return false
            }
            return event.order_index == index
                && event.pitch_ranks == [index + 1]
                && event.start_offset_units == index
                && event.duration_units == 1
        } == true)
    }

    @Test
    func noteGeneratorAnalysisDrivenModeGeneratesDeterministicSequenceFromSyntheticImage() throws {
        let sourceImage = try makeSyntheticSourceImage(
            fileName: "note-generator-success",
            draw: { context, width, height in
                context.setFillColor(gray: 0.0, alpha: 1.0)
                context.fill(CGRect(x: 10, y: 50, width: width - 20, height: 2))
                context.fillEllipse(in: CGRect(x: 16, y: 39, width: 8, height: 8))
                context.fillEllipse(in: CGRect(x: 56, y: 27, width: 8, height: 8))
                context.fillEllipse(in: CGRect(x: 92, y: 35, width: 8, height: 8))
            }
        )

        let module = NoteGeneratorModule(mode: .analysisDriven(LocalImageNoteAnalyzer()))

        let firstOutput = module.generateNotes(
            source_image: sourceImage,
            note_generation_request: NoteGenerationRequest(request_id: "real-request-1")
        )
        let secondOutput = module.generateNotes(
            source_image: sourceImage,
            note_generation_request: NoteGenerationRequest(request_id: "real-request-2")
        )

        #expect(firstOutput.note_generation_result.status == .SUCCESS)
        #expect(firstOutput.note_generation_result.reason == nil)
        #expect(firstOutput.note_sequence == secondOutput.note_sequence)
        #expect(firstOutput.note_sequence?.line_count == 1)
        #expect(firstOutput.note_sequence?.note_count == 3)
        #expect(firstOutput.note_sequence?.events.map(\.order_index) == [0, 1, 2])
        #expect(firstOutput.note_sequence?.events.map(\.start_offset_units) == [0, 1, 2])
        #expect(firstOutput.note_sequence?.events.map(\.duration_units) == [1, 1, 1])
        #expect(firstOutput.note_sequence?.events.map(\.pitch_ranks) == [[3], [1], [2]])
    }

    @Test
    func noteGeneratorAnalysisDrivenModeSelectsBestLineFromMultiplePlausibleSyntheticWires() throws {
        let sourceImage = try makeSyntheticSourceImage(
            fileName: "note-generator-multi-wire-success",
            draw: { context, width, _ in
                context.setFillColor(gray: 0.0, alpha: 1.0)

                context.setLineWidth(2)
                context.move(to: CGPoint(x: 8, y: 18))
                context.addLine(to: CGPoint(x: width - 8, y: 30))
                context.strokePath()

                context.move(to: CGPoint(x: 12, y: 48))
                context.addLine(to: CGPoint(x: width - 12, y: 60))
                context.strokePath()

                context.fillEllipse(in: CGRect(x: 18, y: 11, width: 8, height: 8))
                context.fillEllipse(in: CGRect(x: 48, y: 13, width: 8, height: 8))
                context.fillEllipse(in: CGRect(x: 78, y: 17, width: 8, height: 8))
                context.fillEllipse(in: CGRect(x: 100, y: 19, width: 8, height: 8))

                context.fillEllipse(in: CGRect(x: 22, y: 44, width: 8, height: 8))
                context.fillEllipse(in: CGRect(x: 52, y: 47, width: 8, height: 8))
            }
        )

        let module = NoteGeneratorModule(mode: .analysisDriven(LocalImageNoteAnalyzer()))

        let firstOutput = module.generateNotes(
            source_image: sourceImage,
            note_generation_request: NoteGenerationRequest(request_id: "multi-wire-1")
        )
        let secondOutput = module.generateNotes(
            source_image: sourceImage,
            note_generation_request: NoteGenerationRequest(request_id: "multi-wire-2")
        )

        #expect(firstOutput.note_generation_result.status == .SUCCESS)
        #expect(firstOutput.note_generation_result.reason == nil)
        #expect(firstOutput.note_sequence == secondOutput.note_sequence)
        #expect(firstOutput.note_sequence?.line_count == 1)
        #expect(firstOutput.note_sequence?.note_count == 2)
        #expect(firstOutput.note_sequence?.events.map(\.order_index) == [0, 1])
        #expect(firstOutput.note_sequence?.events.map(\.start_offset_units) == [0, 1])
        #expect(firstOutput.note_sequence?.events.map(\.duration_units) == [1, 1])
    }

    @Test
    func noteGeneratorAnalysisDrivenModeFailsWhenNoValidPowerlineExists() throws {
        let sourceImage = try makeSyntheticSourceImage(
            fileName: "note-generator-no-powerline",
            draw: { _, _, _ in }
        )

        let module = NoteGeneratorModule(mode: .analysisDriven(LocalImageNoteAnalyzer()))
        let output = module.generateNotes(
            source_image: sourceImage,
            note_generation_request: NoteGenerationRequest(request_id: "no-powerline")
        )

        #expect(output.note_sequence == nil)
        #expect(output.note_generation_result.status == .FAILED)
        #expect(output.note_generation_result.reason == .NO_VALID_POWERLINE)
    }

    @Test
    func noteGeneratorAnalysisDrivenModeFailsForDenseNonWireScene() throws {
        let sourceImage = try makeSyntheticSourceImage(
            fileName: "note-generator-non-wire-scene",
            width: 140,
            height: 100,
            draw: { context, width, _ in
                context.setFillColor(gray: 0.0, alpha: 1.0)

                context.setLineWidth(16)
                context.move(to: CGPoint(x: 8, y: 18))
                context.addLine(to: CGPoint(x: width - 12, y: 56))
                context.strokePath()

                let flowerRects = [
                    CGRect(x: 10, y: 10, width: 18, height: 18),
                    CGRect(x: 24, y: 18, width: 16, height: 16),
                    CGRect(x: 40, y: 22, width: 18, height: 18),
                    CGRect(x: 58, y: 28, width: 20, height: 20),
                    CGRect(x: 78, y: 34, width: 18, height: 18),
                    CGRect(x: 96, y: 40, width: 18, height: 18),
                ]

                for rect in flowerRects {
                    context.fillEllipse(in: rect)
                }

                context.fill(CGRect(x: 12, y: 0, width: 6, height: 34))
                context.fill(CGRect(x: 36, y: 8, width: 5, height: 38))
                context.fill(CGRect(x: 62, y: 14, width: 6, height: 42))
                context.fill(CGRect(x: 88, y: 18, width: 5, height: 46))
                context.fill(CGRect(x: 112, y: 24, width: 6, height: 40))
            }
        )

        let module = NoteGeneratorModule(mode: .analysisDriven(LocalImageNoteAnalyzer()))
        let output = module.generateNotes(
            source_image: sourceImage,
            note_generation_request: NoteGenerationRequest(request_id: "non-wire-scene")
        )

        #expect(output.note_sequence == nil)
        #expect(output.note_generation_result.status == .FAILED)
        #expect(output.note_generation_result.reason == .NO_VALID_POWERLINE || output.note_generation_result.reason == .NO_BIRDS_DETECTED)
    }

    @Test
    func noteGeneratorAnalysisDrivenModeFailsWhenPowerlineHasNoBirds() throws {
        let sourceImage = try makeSyntheticSourceImage(
            fileName: "note-generator-no-birds",
            draw: { context, width, _ in
                context.setFillColor(gray: 0.0, alpha: 1.0)
                context.fill(CGRect(x: 10, y: 50, width: width - 20, height: 2))
            }
        )

        let module = NoteGeneratorModule(mode: .analysisDriven(LocalImageNoteAnalyzer()))
        let output = module.generateNotes(
            source_image: sourceImage,
            note_generation_request: NoteGenerationRequest(request_id: "no-birds")
        )

        #expect(output.note_sequence == nil)
        #expect(output.note_generation_result.status == .FAILED)
        #expect(output.note_generation_result.reason == .NO_BIRDS_DETECTED)
    }

    @Test
    func noteGeneratorAnalysisDrivenModeSelectsBestPowerlineWhenMultipleCandidatesExist() {
        let module = NoteGeneratorModule(
            mode: .analysisDriven(
                FixedNoteImageAnalyzer(
                    result: .success([
                        DetectedPowerline(
                            centerY: 20,
                            prominenceScore: 10_000,
                            birds: [DetectedBird(centerX: 10, centerY: 10, darknessScore: 100)],
                            slope: 0.05,
                            spanWidth: 80,
                            supportCount: 42,
                            averageBirdDistance: 3,
                            centralityScore: 0.70
                        ),
                        DetectedPowerline(
                            centerY: 40,
                            prominenceScore: 10_000,
                            birds: [
                                DetectedBird(centerX: 30, centerY: 20, darknessScore: 100),
                                DetectedBird(centerX: 55, centerY: 18, darknessScore: 110),
                                DetectedBird(centerX: 78, centerY: 16, darknessScore: 120),
                            ],
                            slope: 0.02,
                            spanWidth: 110,
                            supportCount: 58,
                            averageBirdDistance: 1,
                            centralityScore: 0.92
                        ),
                    ])
                )
            )
        )
        let sourceImage = SourceImage(
            image_id: "analysis-image",
            origin_method: .SELECT_EXISTING_IMAGE,
            image_reference: "/tmp/not-used"
        )

        let output = module.generateNotes(
            source_image: sourceImage,
            note_generation_request: NoteGenerationRequest(request_id: "ambiguous-powerline")
        )

        #expect(output.note_generation_result.status == .SUCCESS)
        #expect(output.note_generation_result.reason == nil)
        #expect(output.note_sequence?.note_count == 3)
        #expect(output.note_sequence?.events.map(\.order_index) == [0, 1, 2])
    }

    @Test
    func noteGeneratorAnalysisDrivenModeFailsForAmbiguousNoteOrder() {
        let module = NoteGeneratorModule(
            mode: .analysisDriven(
                FixedNoteImageAnalyzer(
                    result: .success([
                        DetectedPowerline(
                            centerY: 30,
                            prominenceScore: 12_000,
                            birds: [
                                DetectedBird(centerX: 10.2, centerY: 18, darknessScore: 100),
                                DetectedBird(centerX: 10.8, centerY: 22, darknessScore: 100),
                            ]
                        )
                    ])
                )
            )
        )
        let sourceImage = SourceImage(
            image_id: "analysis-image",
            origin_method: .SELECT_EXISTING_IMAGE,
            image_reference: "/tmp/not-used"
        )

        let output = module.generateNotes(
            source_image: sourceImage,
            note_generation_request: NoteGenerationRequest(request_id: "ambiguous-order")
        )

        #expect(output.note_sequence == nil)
        #expect(output.note_generation_result.status == .FAILED)
        #expect(output.note_generation_result.reason == .AMBIGUOUS_NOTE_ORDER)
    }

    @Test
    func noteGeneratorAnalysisDrivenModeFailsWhenImageReferenceIsUnreadable() {
        let module = NoteGeneratorModule(mode: .analysisDriven(LocalImageNoteAnalyzer()))
        let sourceImage = SourceImage(
            image_id: "stub-image-invalid",
            origin_method: .SELECT_EXISTING_IMAGE,
            image_reference: "/tmp/perch-notes-missing-image.png"
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
    func audioGeneratorReturnsDeterministicPlayableAudioForValidSequence() throws {
        let module = AudioGeneratorModule()
        let noteSequence = NoteSequence(
            source_image_id: "stub-image-select-existing-image",
            line_count: 3,
            note_count: 3,
            events: [
                NoteEvent(order_index: 0, pitch_ranks: [1], start_offset_units: 0, duration_units: 1),
                NoteEvent(order_index: 1, pitch_ranks: [2], start_offset_units: 1, duration_units: 1),
                NoteEvent(order_index: 2, pitch_ranks: [3], start_offset_units: 2, duration_units: 1),
            ]
        )

        let firstOutput = module.generateAudio(
            note_sequence: noteSequence,
            audio_generation_request: AudioGenerationRequest(request_id: "audio-request-1")
        )
        let secondOutput = module.generateAudio(
            note_sequence: noteSequence,
            audio_generation_request: AudioGenerationRequest(request_id: "audio-request-2")
        )

        let firstAudioData = try #require(audioData(from: firstOutput.generated_audio?.audio_reference))
        let secondAudioData = try #require(audioData(from: secondOutput.generated_audio?.audio_reference))

        #expect(firstOutput.audio_generation_result.status == .SUCCESS)
        #expect(firstOutput.audio_generation_result.reason == nil)
        #expect(firstOutput.generated_audio == secondOutput.generated_audio)
        #expect(firstOutput.generated_audio?.source_image_id == noteSequence.source_image_id)
        #expect(firstOutput.generated_audio?.note_count == noteSequence.note_count)
        #expect(firstOutput.generated_audio?.loopable == true)
        #expect(firstOutput.generated_audio?.audio_reference.hasSuffix(".wav") == true)
        #expect(firstAudioData == secondAudioData)
        #expect(String(decoding: firstAudioData.prefix(4), as: UTF8.self) == "RIFF")
        #expect(String(decoding: firstAudioData.dropFirst(8).prefix(4), as: UTF8.self) == "WAVE")
        #expect(firstAudioData.count > 44)
    }

    @Test
    func audioGeneratorRendersPolyphonicEventsDeterministically() throws {
        let module = AudioGeneratorModule()
        let polyphonicSequence = NoteSequence(
            source_image_id: "polyphonic-source-image",
            line_count: 3,
            note_count: 2,
            events: [
                NoteEvent(order_index: 0, pitch_ranks: [3, 2, 1], start_offset_units: 0, duration_units: 1),
                NoteEvent(order_index: 1, pitch_ranks: [2, 1], start_offset_units: 1, duration_units: 1),
            ]
        )

        let firstOutput = module.generateAudio(
            note_sequence: polyphonicSequence,
            audio_generation_request: AudioGenerationRequest(request_id: "audio-request-polyphonic-1")
        )
        let secondOutput = module.generateAudio(
            note_sequence: polyphonicSequence,
            audio_generation_request: AudioGenerationRequest(request_id: "audio-request-polyphonic-2")
        )

        let firstAudioData = try #require(audioData(from: firstOutput.generated_audio?.audio_reference))
        let secondAudioData = try #require(audioData(from: secondOutput.generated_audio?.audio_reference))

        #expect(firstOutput.audio_generation_result.status == .SUCCESS)
        #expect(firstOutput.audio_generation_result.reason == nil)
        #expect(firstOutput.generated_audio == secondOutput.generated_audio)
        #expect(firstAudioData == secondAudioData)
        #expect(firstOutput.generated_audio?.note_count == 2)
    }

    @Test
    func audioGeneratorRendersMixedMonophonicAndPolyphonicEvents() {
        let module = AudioGeneratorModule()
        let mixedSequence = NoteSequence(
            source_image_id: "mixed-source-image",
            line_count: 3,
            note_count: 3,
            events: [
                NoteEvent(order_index: 0, pitch_ranks: [3], start_offset_units: 0, duration_units: 1),
                NoteEvent(order_index: 1, pitch_ranks: [3, 1], start_offset_units: 1, duration_units: 1),
                NoteEvent(order_index: 2, pitch_ranks: [2], start_offset_units: 2, duration_units: 1),
            ]
        )

        let output = module.generateAudio(
            note_sequence: mixedSequence,
            audio_generation_request: AudioGenerationRequest(request_id: "audio-request-mixed")
        )

        #expect(output.audio_generation_result.status == .SUCCESS)
        #expect(output.audio_generation_result.reason == nil)
        #expect(output.generated_audio?.note_count == mixedSequence.note_count)
        #expect(output.generated_audio?.loopable == true)
    }

    @Test
    func audioGeneratorFailsWhenSequenceStructureIsInvalid() {
        let module = AudioGeneratorModule()
        let invalidSequence = NoteSequence(
            source_image_id: "stub-image-select-existing-image",
            line_count: 2,
            note_count: 3,
            events: [
                NoteEvent(order_index: 0, pitch_ranks: [1], start_offset_units: 0, duration_units: 1),
                NoteEvent(order_index: 2, pitch_ranks: [2], start_offset_units: 2, duration_units: 1),
            ]
        )

        let output = module.generateAudio(
            note_sequence: invalidSequence,
            audio_generation_request: AudioGenerationRequest(request_id: "audio-request-invalid-structure")
        )

        #expect(output.generated_audio == nil)
        #expect(output.audio_generation_result.status == .FAILED)
        #expect(output.audio_generation_result.reason == .INVALID_EVENT_ORDER)
    }

    @Test
    func audioGeneratorFailsWhenPitchRanksAreInvalid() {
        let module = AudioGeneratorModule()
        let invalidSequence = NoteSequence(
            source_image_id: "invalid-pitches-source-image",
            line_count: 3,
            note_count: 2,
            events: [
                NoteEvent(order_index: 0, pitch_ranks: [2, 2], start_offset_units: 0, duration_units: 1),
                NoteEvent(order_index: 1, pitch_ranks: [1], start_offset_units: 1, duration_units: 1),
            ]
        )

        let output = module.generateAudio(
            note_sequence: invalidSequence,
            audio_generation_request: AudioGenerationRequest(request_id: "audio-request-invalid-pitches")
        )

        #expect(output.generated_audio == nil)
        #expect(output.audio_generation_result.status == .FAILED)
        #expect(output.audio_generation_result.reason == .INVALID_NOTE_SEQUENCE)
    }

    @Test
    func audioGeneratorFailsWhenLineCountIsInvalid() {
        let module = AudioGeneratorModule()
        let invalidSequence = NoteSequence(
            source_image_id: "invalid-line-count-source-image",
            line_count: 0,
            note_count: 1,
            events: [
                NoteEvent(order_index: 0, pitch_ranks: [1], start_offset_units: 0, duration_units: 1),
            ]
        )

        let output = module.generateAudio(
            note_sequence: invalidSequence,
            audio_generation_request: AudioGenerationRequest(request_id: "audio-request-invalid-line-count")
        )

        #expect(output.generated_audio == nil)
        #expect(output.audio_generation_result.status == .FAILED)
        #expect(output.audio_generation_result.reason == .INVALID_NOTE_SEQUENCE)
    }

    @Test
    func audioGeneratorFailsWhenSequenceIsEmpty() {
        let module = AudioGeneratorModule()
        let emptySequence = NoteSequence(
            source_image_id: "stub-image-select-existing-image",
            line_count: 1,
            note_count: 0,
            events: []
        )

        let output = module.generateAudio(
            note_sequence: emptySequence,
            audio_generation_request: AudioGenerationRequest(request_id: "audio-request-empty")
        )

        #expect(output.generated_audio == nil)
        #expect(output.audio_generation_result.status == .FAILED)
        #expect(output.audio_generation_result.reason == .INVALID_NOTE_SEQUENCE)
    }

    @Test
    func audioGeneratorFailsWhenTimingIsInvalid() {
        let module = AudioGeneratorModule()
        let invalidSequence = NoteSequence(
            source_image_id: "stub-image-select-existing-image",
            line_count: 2,
            note_count: 2,
            events: [
                NoteEvent(order_index: 0, pitch_ranks: [1], start_offset_units: 0, duration_units: 1),
                NoteEvent(order_index: 1, pitch_ranks: [2], start_offset_units: 4, duration_units: 1),
            ]
        )

        let output = module.generateAudio(
            note_sequence: invalidSequence,
            audio_generation_request: AudioGenerationRequest(request_id: "audio-request-invalid")
        )

        #expect(output.generated_audio == nil)
        #expect(output.audio_generation_result.status == .FAILED)
        #expect(output.audio_generation_result.reason == .INVALID_TIMING)
    }

    @Test
    func corePipelineEntryRunnerRunsRealPipelineForSelectedImage() throws {
        let sourceImage = try makeSyntheticSourceImage(
            fileName: "core-pipeline-real-demo-success",
            draw: { context, width, _ in
                context.setFillColor(gray: 0.0, alpha: 1.0)
                context.fill(CGRect(x: 10, y: 50, width: width - 20, height: 2))
                context.fillEllipse(in: CGRect(x: 16, y: 39, width: 8, height: 8))
                context.fillEllipse(in: CGRect(x: 56, y: 27, width: 8, height: 8))
                context.fillEllipse(in: CGRect(x: 92, y: 35, width: 8, height: 8))
            }
        )
        let responder = FixedImageAcquisitionResponder(
            response: ImageAcquisitionResponse(
                status: .COMPLETED,
                image_count: 1,
                image_reference: sourceImage.image_reference
            )
        )
        let runner = CorePipelineEntryRunner()

        let run = runner.runRealPipeline(
            imageAcquisitionRequest: ImageAcquisitionRequest(acquisition_method: .SELECT_EXISTING_IMAGE),
            cameraPermissionState: CameraPermissionState(state: .UNKNOWN),
            acquisitionResponder: responder
        )

        #expect(run.request.image_acquisition_request.acquisition_method == .SELECT_EXISTING_IMAGE)
        #expect(run.result.final_pipeline_status == .SUCCESS)
        #expect(run.result.image_acquisition_outcome.image_acquisition_result.status == .SUCCESS)
        #expect(run.result.note_generation_outcome?.note_generation_result.status == .SUCCESS)
        #expect(run.result.audio_generation_outcome?.audio_generation_result.status == .SUCCESS)
        #expect(run.result.audio_generation_outcome?.generated_audio?.audio_reference.hasSuffix(".wav") == true)
        #expect(run.logLines.contains(where: { $0.contains("pipeline started") }))
        #expect(run.logLines.contains(where: { $0.contains("image acquisition result") }))
        #expect(run.logLines.contains(where: { $0.contains("note generation result") }))
        #expect(run.logLines.contains(where: { $0.contains("audio generation result") }))
    }
}

private final class FixedImageAcquisitionResponder: ImageAcquisitionResponding {
    private let response: ImageAcquisitionResponse

    init(response: ImageAcquisitionResponse) {
        self.response = response
    }

    func acquireImageResponse(for acquisitionMethod: ImageAcquisitionMethod) -> ImageAcquisitionResponse {
        response
    }
}

private final class FixedNoteImageAnalyzer: NoteImageAnalyzing {
    private let result: NoteImageAnalysisResult

    init(result: NoteImageAnalysisResult) {
        self.result = result
    }

    func analyze(source_image: SourceImage) -> NoteImageAnalysisResult {
        result
    }
}

private func makeSyntheticSourceImage(
    fileName: String,
    width: Int = 120,
    height: Int = 80,
    draw: (CGContext, Int, Int) -> Void
) throws -> SourceImage {
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(fileName)-\(UUID().uuidString).png")

    let colorSpace = CGColorSpaceCreateDeviceGray()
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.none.rawValue
    ) else {
        throw SyntheticImageError.contextCreationFailed
    }

    context.setFillColor(gray: 1.0, alpha: 1.0)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    draw(context, width, height)

    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw SyntheticImageError.imageEncodingFailed
    }

    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw SyntheticImageError.imageEncodingFailed
    }

    return SourceImage(
        image_id: "synthetic-\(fileName)",
        origin_method: .SELECT_EXISTING_IMAGE,
        image_reference: fileURL.absoluteString
    )
}

private enum SyntheticImageError: Error {
    case contextCreationFailed
    case imageEncodingFailed
}

private func audioData(from audioReference: String?) -> Data? {
    guard let audioReference else {
        return nil
    }

    if let url = URL(string: audioReference), url.isFileURL {
        return try? Data(contentsOf: url)
    }

    let fileURL = URL(fileURLWithPath: audioReference)
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
        return nil
    }

    return try? Data(contentsOf: fileURL)
}
