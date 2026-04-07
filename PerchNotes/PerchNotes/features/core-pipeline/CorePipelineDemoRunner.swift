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
    func runStubDemo() -> CorePipelineDemoRun {
        let request = CorePipelineRequest(
            image_acquisition_request: ImageAcquisitionRequest(acquisition_method: .CAPTURE_NEW_IMAGE),
            camera_permission_state: CameraPermissionState(state: .GRANTED)
        )

        var logLines: [String] = []
        let logHandler: (String) -> Void = { message in
            logLines.append(message)
        }

        let orchestrator = CorePipelineOrchestrator(
            imageProvider: ImageProviderModule(logHandler: logHandler),
            noteGenerator: NoteGeneratorModule(logHandler: logHandler),
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
