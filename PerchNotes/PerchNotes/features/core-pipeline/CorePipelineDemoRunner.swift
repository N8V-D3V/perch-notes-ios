//
//  CorePipelineDemoRunner.swift
//  PerchNotes
//
//  Created by Codex on 4/7/26.
//

import Foundation

struct CorePipelineDemoRun {
    let request: CorePipelineRequest
    let result: CorePipelineResult
    let logLines: [String]
}

struct CorePipelineDemoRunner {
    func runRealPipeline(
        imageAcquisitionRequest: ImageAcquisitionRequest,
        cameraPermissionState: CameraPermissionState,
        acquisitionResponder: any ImageAcquisitionResponding
    ) -> CorePipelineDemoRun {
        let request = CorePipelineRequest(
            image_acquisition_request: imageAcquisitionRequest,
            camera_permission_state: cameraPermissionState
        )
        var logLines: [String] = []
        let logHandler: (String) -> Void = { message in
            logLines.append(message)
        }

        let orchestrator = CorePipelineOrchestrator(
            imageProvider: ImageProviderModule(mode: .responseDriven(acquisitionResponder), logHandler: logHandler),
            noteGenerator: NoteGeneratorModule(mode: .analysisDriven(LocalImageNoteAnalyzer()), logHandler: logHandler),
            audioGenerator: AudioGeneratorModule(logHandler: logHandler),
            logHandler: logHandler
        )
        let result = orchestrator.runPipeline(request: request)

        return CorePipelineDemoRun(
            request: request,
            result: result,
            logLines: logLines
        )
    }
}
