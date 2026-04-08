//
//  CorePipelineEntryView.swift
//  PerchNotes
//
//  Created by Codex on 4/7/26.
//

import AVFoundation
import Foundation
import SwiftUI
import UIKit

struct CorePipelineEntryView: View {
    @State private var latestRun: CorePipelineEntryRun?
    @State private var activeAcquisitionMethod: ImageAcquisitionMethod?
    @State private var pendingRunMethod: ImageAcquisitionMethod?
    @State private var pendingCameraPermissionState = CameraPermissionState(state: .UNKNOWN)
    @State private var acquisitionResponder = InteractiveImageAcquisitionResponder()
    @State private var isRequestingCameraPermission = false
    @State private var isSuccessToastVisible = false
    @State private var successToastDismissWorkItem: DispatchWorkItem?
    @StateObject private var loopPlaybackController = CorePipelineLoopPlaybackController()

    private let entryRunner = CorePipelineEntryRunner()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                headerSection
                successToastSection
                failureBannerSection
                previewSection
                centralActionSection
                Spacer(minLength: 0)
                controlsSection
            }
            .padding(20)
            .navigationTitle("PerchNotes")
            .sheet(item: $activeAcquisitionMethod, onDismiss: handleAcquisitionDismissal) { acquisitionMethod in
                ImageProviderAcquisitionSheet(
                    acquisitionMethod: acquisitionMethod,
                    responder: acquisitionResponder,
                    onComplete: {
                        completeAcquisition(for: acquisitionMethod)
                    }
                )
                .ignoresSafeArea()
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Turn Perches Into Loops")
                .font(.title.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Choose or capture a bird-on-powerline image and PerchNotes will turn it into a musical loop.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Clear, high-contrast powerlines with visible birds work best.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var successToastSection: some View {
        if isSuccessToastVisible {
            Text("Loop ready")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.green.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.35), lineWidth: 1)
                }
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var failureBannerSection: some View {
        if let latestRun,
           let failurePresentation = CorePipelineFailurePresentation.make(from: latestRun.result) {
            VStack(alignment: .leading, spacing: 6) {
                Text(failurePresentation.title)
                    .font(.subheadline.weight(.semibold))

                Text(failurePresentation.message)
                    .font(.subheadline)

                if let recoveryHint = failurePresentation.recoveryHint {
                    Text(recoveryHint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.35), lineWidth: 1)
            }
        }
    }

    private var controlsSection: some View {
        VStack(spacing: 12) {
            Button("Choose Photo") {
                startSelectionPipeline()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .disabled(isBusy)

            Button("Take Photo") {
                startCapturePipeline()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            .disabled(isBusy)

            if isRequestingCameraPermission {
                Text("Checking camera access...")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if activeAcquisitionMethod != nil {
                Text("Waiting for your image...")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var previewSection: some View {
        let preview = previewState

        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemBackground))

            switch preview {
            case .image(let image):
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 24))

            case .cameraReady:
                previewPlaceholder(
                    systemImage: "camera.viewfinder",
                    title: "Camera Preview",
                    message: "Take a perch photo and PerchNotes will bring it back here."
                )

            case .empty:
                previewPlaceholder(
                    systemImage: "photo.on.rectangle.angled",
                    title: "Your Photo Appears Here",
                    message: "Choose a photo or take a new one to turn perches into a loop."
                )
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var centralActionSection: some View {
        VStack(spacing: 12) {
            if let generatedAudio = latestRun?.result.audio_generation_outcome?.generated_audio,
               latestRun?.result.final_pipeline_status == .SUCCESS {
                playbackControls(for: generatedAudio)
            } else {
                VStack(spacing: 8) {
                    Text("Ready When You Are")
                        .font(.headline.weight(.semibold))

                    Text("Pick a bird-on-powerline image to create a loop you can play right here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var previewState: PreviewState {
        if let sourceImage = latestRun?.result.image_acquisition_outcome.source_image,
           let uiImage = previewImage(from: sourceImage.image_reference) {
            return .image(uiImage)
        }

        if activeAcquisitionMethod == .CAPTURE_NEW_IMAGE {
            return .cameraReady
        }

        return .empty
    }

    private func previewImage(from imageReference: String) -> UIImage? {
        if let url = URL(string: imageReference), url.isFileURL {
            return UIImage(contentsOfFile: url.path)
        }

        return UIImage(contentsOfFile: imageReference)
    }

    @ViewBuilder
    private func previewPlaceholder(systemImage: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline.weight(.semibold))

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    @ViewBuilder
    private func playbackControls(for generatedAudio: GeneratedAudio) -> some View {
        let isPlayingCurrentLoop =
            loopPlaybackController.isPlaying
            && loopPlaybackController.activeAudioReference == generatedAudio.audio_reference

        VStack(spacing: 12) {
            Button(isPlayingCurrentLoop ? "Stop Loop" : "Play Loop") {
                loopPlaybackController.togglePlayback(audioReference: generatedAudio.audio_reference)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity)

            if let playbackErrorMessage = loopPlaybackController.playbackErrorMessage {
                Text(playbackErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var isBusy: Bool {
        activeAcquisitionMethod != nil || isRequestingCameraPermission
    }

    private func startSelectionPipeline() {
        loopPlaybackController.stopPlayback()
        hideSuccessToast()
        latestRun = nil
        pendingRunMethod = .SELECT_EXISTING_IMAGE
        pendingCameraPermissionState = CameraPermissionState(state: .UNKNOWN)
        activeAcquisitionMethod = .SELECT_EXISTING_IMAGE
    }

    private func startCapturePipeline() {
        loopPlaybackController.stopPlayback()
        hideSuccessToast()
        latestRun = nil
        pendingRunMethod = .CAPTURE_NEW_IMAGE

        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            acquisitionResponder.recordFailure(for: .CAPTURE_NEW_IMAGE)
            runPipeline(
                acquisitionMethod: .CAPTURE_NEW_IMAGE,
                cameraPermissionState: CameraPermissionState(state: .GRANTED)
            )
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            pendingCameraPermissionState = CameraPermissionState(state: .GRANTED)
            activeAcquisitionMethod = .CAPTURE_NEW_IMAGE

        case .notDetermined:
            isRequestingCameraPermission = true
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    isRequestingCameraPermission = false
                    if granted {
                        pendingCameraPermissionState = CameraPermissionState(state: .GRANTED)
                        activeAcquisitionMethod = .CAPTURE_NEW_IMAGE
                    } else {
                        runPipeline(
                            acquisitionMethod: .CAPTURE_NEW_IMAGE,
                            cameraPermissionState: CameraPermissionState(state: .DENIED)
                        )
                    }
                }
            }

        case .denied, .restricted:
            runPipeline(
                acquisitionMethod: .CAPTURE_NEW_IMAGE,
                cameraPermissionState: CameraPermissionState(state: .DENIED)
            )

        @unknown default:
            runPipeline(
                acquisitionMethod: .CAPTURE_NEW_IMAGE,
                cameraPermissionState: CameraPermissionState(state: .UNKNOWN)
            )
        }
    }

    private func handleAcquisitionDismissal() {
        guard let pendingRunMethod else {
            return
        }

        completeAcquisition(for: pendingRunMethod)
    }

    private func completeAcquisition(for acquisitionMethod: ImageAcquisitionMethod) {
        guard pendingRunMethod == acquisitionMethod else {
            return
        }

        runPipeline(
            acquisitionMethod: acquisitionMethod,
            cameraPermissionState: pendingCameraPermissionState
        )
    }

    private func runPipeline(
        acquisitionMethod: ImageAcquisitionMethod,
        cameraPermissionState: CameraPermissionState
    ) {
        latestRun = entryRunner.runRealPipeline(
            imageAcquisitionRequest: ImageAcquisitionRequest(acquisition_method: acquisitionMethod),
            cameraPermissionState: cameraPermissionState,
            acquisitionResponder: acquisitionResponder
        )

        if latestRun?.result.final_pipeline_status == .SUCCESS {
            showSuccessToast()
        } else {
            loopPlaybackController.stopPlayback()
            hideSuccessToast()
        }

        pendingRunMethod = nil
        activeAcquisitionMethod = nil
    }

    private func showSuccessToast() {
        successToastDismissWorkItem?.cancel()
        isSuccessToastVisible = true

        let dismissWorkItem = DispatchWorkItem {
            isSuccessToastVisible = false
        }
        successToastDismissWorkItem = dismissWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: dismissWorkItem)
    }

    private func hideSuccessToast() {
        successToastDismissWorkItem?.cancel()
        successToastDismissWorkItem = nil
        isSuccessToastVisible = false
    }
}

private enum PreviewState {
    case image(UIImage)
    case cameraReady
    case empty
}

extension ImageAcquisitionMethod: Identifiable {
    var id: String {
        rawValue
    }
}

private struct CorePipelineFailurePresentation {
    let title: String
    let message: String
    let recoveryHint: String?

    static func make(from result: CorePipelineResult) -> CorePipelineFailurePresentation? {
        guard result.final_pipeline_status == .FAILED else {
            return nil
        }

        if let reason = result.audio_generation_outcome?.audio_generation_result.reason {
            return fromAudioReason(reason)
        }

        if let reason = result.note_generation_outcome?.note_generation_result.reason {
            return fromNoteReason(reason)
        }

        if let reason = result.image_acquisition_outcome.image_acquisition_result.reason {
            return fromImageReason(reason)
        }

        return CorePipelineFailurePresentation(
            title: "We couldn’t turn that photo into a loop.",
            message: "Try another image and see if PerchNotes can make a clearer musical pattern from it.",
            recoveryHint: "Photos with visible birds on a single clear powerline work best."
        )
    }

    private static func fromImageReason(
        _ reason: ImageAcquisitionFailureReason
    ) -> CorePipelineFailurePresentation {
        switch reason {
        case .CAMERA_PERMISSION_REQUIRED:
            return CorePipelineFailurePresentation(
                title: "Camera access is turned off.",
                message: "PerchNotes needs camera access to take a new photo.",
                recoveryHint: "Allow camera access or choose a photo from your library instead."
            )
        case .NO_IMAGE_ACQUIRED, .IMAGE_ACQUISITION_CANCELLED:
            return CorePipelineFailurePresentation(
                title: "No photo was selected.",
                message: "PerchNotes didn’t receive an image to turn into a loop.",
                recoveryHint: "Choose a photo or take a new one to try again."
            )
        case .MULTIPLE_IMAGES_NOT_SUPPORTED:
            return CorePipelineFailurePresentation(
                title: "Choose one photo at a time.",
                message: "PerchNotes can only create a loop from a single image.",
                recoveryHint: "Pick one bird-on-powerline photo and try again."
            )
        case .INVALID_SOURCE_IMAGE, .IMAGE_ACQUISITION_FAILED:
            return CorePipelineFailurePresentation(
                title: "We couldn’t use that photo.",
                message: "PerchNotes couldn’t read the selected image.",
                recoveryHint: "Try another photo from your camera or library."
            )
        }
    }

    private static func fromNoteReason(
        _ reason: NoteGenerationFailureReason
    ) -> CorePipelineFailurePresentation {
        switch reason {
        case .NO_VALID_POWERLINE:
            return CorePipelineFailurePresentation(
                title: "We couldn’t find a clear powerline in that photo.",
                message: "PerchNotes needs a visible wire before it can turn birds into notes.",
                recoveryHint: "Try a photo with one strong, easy-to-see powerline."
            )
        case .NO_BIRDS_DETECTED:
            return CorePipelineFailurePresentation(
                title: "We couldn’t find birds on the wire in that photo.",
                message: "PerchNotes found the line, but not any birds it could turn into notes.",
                recoveryHint: "Try a photo where the birds stand out more clearly from the background."
            )
        case .AMBIGUOUS_POWERLINE_SELECTION:
            return CorePipelineFailurePresentation(
                title: "That photo has too many possible wires.",
                message: "PerchNotes couldn’t confidently choose one powerline to interpret.",
                recoveryHint: "Try a photo with one main wire and fewer overlapping lines."
            )
        case .IMAGE_ANALYSIS_FAILED:
            return CorePipelineFailurePresentation(
                title: "We couldn’t read that photo clearly enough.",
                message: "PerchNotes couldn’t analyze the image for notes.",
                recoveryHint: "Try a brighter, sharper photo with a simpler background."
            )
        case .AMBIGUOUS_NOTE_ORDER:
            return CorePipelineFailurePresentation(
                title: "We couldn’t place the birds in a clear order.",
                message: "PerchNotes couldn’t reliably map the birds into a left-to-right melody.",
                recoveryHint: "Try a photo where the birds are more clearly separated along the wire."
            )
        }
    }

    private static func fromAudioReason(
        _ reason: AudioGenerationFailureReason
    ) -> CorePipelineFailurePresentation {
        switch reason {
        case .MISSING_NOTE_SEQUENCE, .EMPTY_NOTE_SEQUENCE, .INVALID_NOTE_TIMING, .INVALID_NOTE_SEQUENCE:
            return CorePipelineFailurePresentation(
                title: "We couldn’t turn that photo into a loop.",
                message: "PerchNotes couldn’t build a playable loop from the notes for this image.",
                recoveryHint: "Try another photo and see if it produces a clearer pattern."
            )
        case .AUDIO_GENERATION_FAILED:
            return CorePipelineFailurePresentation(
                title: "We couldn’t finish the loop.",
                message: "PerchNotes found the pattern, but the audio didn’t finish rendering.",
                recoveryHint: "Try running the same photo again or choose a different one."
            )
        }
    }
}
